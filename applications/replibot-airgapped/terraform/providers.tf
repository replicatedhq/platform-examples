locals {
  default_tags = {
    "region" : var.aws_region,
    "env" : var.env,
    "iac:git" : "terraform-airgap-aws",
    "iac:tool" : "terraform"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.account_owner

  default_tags {
    tags = merge(local.default_tags, {
      "account:owner" : var.account_owner,
    })
  }
}

