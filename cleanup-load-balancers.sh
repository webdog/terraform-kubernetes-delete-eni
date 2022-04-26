#!/usr/bin/env bash
set -e

VPC_ID=${VPC_ID}
ELASTIC_LOAD_BALANCERS=$(aws elb describe-load-balancers)

# Security group description auto-generated by Kubernetes, and not created or managed by terraform
THIS_SEARCH="Security group for Kubernetes ELB"
KUBE_SGS=($(aws ec2 describe-security-groups --filters Name=vpc-id,Values="${VPC_ID}" | jq --arg str "$THIS_SEARCH" '.SecurityGroups[] | select(.Description | contains($str)) | .GroupId' | tr -d "\""))

# step through each security group created by kubernetes
for sg in "${KUBE_SGS[@]}"
 do
  # Locate security groups that have ingress rules referencing this security group. If k8s creates a security group,
  # EKS automatically adds an ingress route to it, inside the default security group created by EKS.
  INGRESS_RULES_REFERENCING_SG=($(aws ec2 describe-security-groups --filters Name=vpc-id,Values="${VPC_ID}" Name=ip-permission.group-id,Values="${sg}" | jq --arg sg $sg -r  '.SecurityGroups[].IpPermissions[].UserIdGroupPairs[] | select(.GroupId != $sg) | .GroupId' | tr -d "\""))
  for grp in "${INGRESS_RULES_REFERENCING_SG[@]}"
  do
    # When iterating these groups, capture the rules of the security group, specifically filtering on the kubernetes security group id
    # and then finding the value of it in the `ReferencedGroupInfo` block. That block doesn't always exist, but it always exists
    # when there is a security group referenced, such as `$sg`. Once found, capture the specific rule ids into
    # an array.
    grp_rules=($(aws ec2 describe-security-group-rules --filters Name=group-id,Values=$grp | jq --arg sg $sg -r '.SecurityGroupRules[] | select(.ReferencedGroupInfo.GroupId == $sg) | .SecurityGroupRuleId'))
    for rules in "${grp_rules[@]}"
      do
      # Loop through the grp_rules that include our security group, and revoke that rule. This allows us to
      # delete the security group later on, as this relationship isn't removed when the underlying Load Balancer resources
      # are destroyed.
      aws ec2 revoke-security-group-ingress --group-id $grp --security-group-rule-ids $rules
      done
  done

  # This security group is in these Load Balancers
  JQ_DESCRIPTION=(jq --arg vpc "$VPC_ID" -r '.LoadBalancerDescriptions[] | select(.VPCId == $vpc) | .SecurityGroups')
  in_array=$(echo $ELASTIC_LOAD_BALANCERS | "${JQ_DESCRIPTION[@]}" | grep -o $sg | wc -w)
  # Each Load Balancer has an array of security group ids, if the kube created SG is there return a value of 1.
  if [[ $in_array -eq 1 ]]
  then
    # This jq statement and the following lb_name scan the LoadBalancers in a given VPC for this security group id, and then return the name.
    # Return none so the following aws elb destroy command will fail.
    JQ_FIND=(jq --arg sgroup "$sg" --arg vpc "$VPC_ID" -r '.LoadBalancerDescriptions[] | select(.VPCId == $vpc) | if (.SecurityGroups as $g | $sgroup | IN($g[]) ) then .LoadBalancerName else empty end')
    lb_name=$(echo $ELASTIC_LOAD_BALANCERS | "${JQ_FIND[@]}")
    aws elb delete-load-balancer --load-balancer-name "${lb_name}"

    # jq query string
    JQ_ENI_IDS=(jq --arg sg $sg -r '.NetworkInterfaces[] | select(.Groups[] | .GroupId == $sg) | .NetworkInterfaceId')
    enis_attached_to_sg=($(aws ec2 describe-network-interfaces | "${JQ_ENI_IDS[@]}" | tr -d "\""))

    # jq query string
    JQ_ENI_STATUS=(jq --arg sg $sg -r '.NetworkInterfaces[] | select(.Groups[] | .GroupId == $sg) | .Status')
    # Omce deleted, the ENIs are still around for a little bit. If we try to delete the security group too quickly
    # AWS will let us know that the security group still has dependencies. In this case, we'll capture those ENI
    # IDS, watch their status, and once all-clear, then delete the security group.This note covers line 50 to the end
    # of the file.
    echo "Checking status of ENIs"
    for eni_id in ${enis_attached_to_sg[@]}
    do
      eni_status=($(aws ec2 describe-network-interfaces | "${JQ_ENI_STATUS[@]}" | tr -d "\""))
      for status in ${eni_status[@]}
      do
        if [[ status != "available" ]]
        then
          echo "One or more ENIs in $sg still not available after Load Balancer deleted. Waiting 5 seconds to check again"
          echo "$eni_id : $eni_status"
          sleep 5
          eni_status=($(aws ec2 describe-network-interfaces | "${JQ_ENI_STATUS[@]}" | tr -d "\""))
      # The for loop ends when the iterated $eni becomes available, meaning it has been detached and we can delete this security group. The deletion of the ENI taken care of by AWS.
      fi
    done
  done
  fi
  echo "Deleting security group $sg"
  aws ec2 delete-security-group --group-id $sg
  echo "Security group $sg deleted"
done

echo "Script has completed. Your orphaned ENIs have been removed from your account. Validate in the AWS console if unexpected behavior is returned"
