## terraform-kubernetes-delete-eni

A utility module to destroy the Elastic Network Interfaces associated with Elastic Load Balancers that are created by EKS. Terraform is unaware of these resources, and can become stuck during destroy when attempting to remove the subnets from the EKS VPC which still has ENIs attached to an Elastic Load Balancer. A re-run of terraform destroy usually resolves this, but this module helps terraform complete successfully on the first time.

There are known issues with delays in the AWS API, so this script is not always successful, and may require the manual removing of resources (Which would have to have been removed anyway, regardless of this utility), or re-running the module to finish removing resources from your account. This usually occurs when there is latency internal to the AWS API updating an ENIs status to *Available*.

This script intakes a VPC ID and region, iterating through the security groups

```hcl

module "remove_eni" {
    source = "github.com/webdog/terraform-kubernetes/delete-eni"
    vpc_id = "your_vpc_id"
    region = "us-east-1"
}

```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 3.66.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.1.1 |
| <a href="https://aws.amazon.com/cli/"></a> [AWS CLI](https://aws.amazon.com/cli) | 2.5.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | 3.1.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.cleanup](https://registry.terraform.io/providers/hashicorp/null/3.1.1/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_region"></a> [region](#input\_region) | AWS region where this module is used | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID that is used in this module | `string` | n/a | yes |

## Outputs

No outputs.
