data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_key_pair" "ec" {
  key_name = var.key_name
}

resource "aws_instance" "ec" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.xlarge"
  subnet_id     = var.private_subnets[0]
  security_groups = [aws_security_group.ec.id]
  key_name      = data.aws_key_pair.ec.key_name

  tags = {
    Name = "${var.name_prefix}-airgap-embedded-cluster"
  }

  root_block_device {
    iops = 10000
    volume_size = 100
    volume_type = "io2"
  }

}
