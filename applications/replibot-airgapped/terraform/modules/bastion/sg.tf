resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-instance-sg"
  vpc_id      = var.vpc_id
  description = "Security group for airgap bastion instance"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.bastion.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
}

resource "aws_security_group_rule" "ingress_bastion" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  cidr_blocks       = var.ingress_cidr_blocks
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

resource "aws_security_group_rule" "ingress_bastion_allow_ssh" {
  security_group_id = aws_security_group.bastion.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
}
