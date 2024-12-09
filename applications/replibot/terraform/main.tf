module "vpc" {
  source = "./modules/vpc"

  vpc_cidr_block        = var.vpc_cidr_block
  name_prefix           = "${var.env}-airgap"
  public_cidr_block_map = var.public_cidr_block_map
  private_cidr_block_map = var.private_cidr_block_map
}

module "bastion" {
  source = "./modules/bastion"

  vpc_id            = module.vpc.vpc_id
  name_prefix       = "${var.env}-airgap"
  public_subnets    = [for k, v in module.vpc.public_subnets : v.id]
  ingress_cidr_blocks= [module.vpc.vpc_cidr_block]
  key_name          = var.key_name
  airgap_download_script = var.airgap_download_script
}

module "airgap" {
  source = "./modules/airgap"

  vpc_id            = module.vpc.vpc_id
  name_prefix       = "${var.env}-airgap"
  private_subnets   = [for k, v in module.vpc.private_subnets : v.id]
  ingress_cidr_blocks= [module.vpc.vpc_cidr_block]
  key_name          = var.key_name
}
