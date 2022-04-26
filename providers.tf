terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "3.66.0"
    }
    null = {
        source = "hashicorp/null"
        version = "3.1.1"
    }
  }
}

provider "aws" {
    region = var.region
}

provider "null" {}