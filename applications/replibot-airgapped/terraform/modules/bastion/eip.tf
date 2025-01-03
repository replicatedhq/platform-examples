# EIP
resource "aws_eip" "bastion" {
  tags = {
    Name = "${var.name_prefix}-bastion-eip"
  }

  lifecycle {
    prevent_destroy = false
  }
}
