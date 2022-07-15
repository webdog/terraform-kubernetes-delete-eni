locals {
  vpc_id              = var.vpc_id
  region              = var.region
}

resource "null_resource" "cleanup" {
  triggers = {
    # https://github.com/hashicorp/terraform/issues/23679#issuecomment-886020367
    invokes_me_everytime = uuid()
    vpc_id               = local.vpc_id
    region               = var.region
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = path.module
    environment = {
      VPC_ID             = self.triggers.vpc_id
      AWS_DEFAULT_REGION = self.triggers.region
    }
    command = "bash cleanup-load-balancers.sh"
  }
  lifecycle {
    ignore_changes = all
  }
}
