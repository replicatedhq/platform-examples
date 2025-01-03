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

# data "aws_ami" "aws_linux" {
#   most_recent = true
#   owners      = ["amazon"]
#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }
#   filter {
#     name   = "root-device-type"
#     values = ["ebs"]
#   }
#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*"]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
#   filter {
#     name   = "block-device-mapping.volume-type"
#     values = ["gp2"]
#   }
# }

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

data "aws_key_pair" "bastion" {
  key_name = var.key_name
}

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = var.public_subnets[0]
  security_groups = [aws_security_group.bastion.id]
  key_name      = data.aws_key_pair.bastion.key_name

  tags = {
    Name = "${var.name_prefix}-bastion"
  }

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

   user_data_base64 = base64encode(templatefile("${path.module}/init.tpl", {
    airgap_download_script     = "${var.airgap_download_script}"
  }))
}
