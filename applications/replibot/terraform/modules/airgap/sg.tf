resource "aws_security_group" "ec" {
  name        = "${var.name_prefix}-ec-instance-sg"
  vpc_id      = var.vpc_id
  description = "Security group for airgap ec instance"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.ec.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
}

resource "aws_security_group_rule" "ingress_ec" {
  security_group_id = aws_security_group.ec.id
  type              = "ingress"
  cidr_blocks       = var.ingress_cidr_blocks
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}
