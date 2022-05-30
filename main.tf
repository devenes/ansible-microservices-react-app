resource "aws_instance" "control_node" {
  ami                    = var.instance_ami
  instance_type          = var.controller_instance_type
  key_name               = var.keyname
  iam_instance_profile   = aws_iam_instance_profile.ec2full.name
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  tags = {
    Name  = "ansible_control"
    stack = "ansible_project"
  }
}

resource "aws_instance" "managed_node" {
  ami                    = var.instance_ami
  count                  = var.instance_count
  instance_type          = var.managed_instance_type
  key_name               = var.keyname
  vpc_security_group_ids = [aws_security_group.tf-sec-gr.id]
  tags = {
    Name        = "ansible_${element(var.tags, count.index)}"
    stack       = "ansible_project"
    environment = "development"
  }
  user_data = file("managed_user_data.sh")
}

resource "aws_iam_role" "ec2full" {
  name = "projectec2full"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
}

resource "aws_iam_instance_profile" "ec2full" {
  name = "projectec2full"
  role = aws_iam_role.ec2full.name
}

resource "aws_security_group" "tf-sec-gr" {
  name = var.security_group
  tags = {
    Name = var.security_group
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "config" {
  depends_on = [aws_instance.control_node]
  connection {
    host        = aws_instance.control_node.public_ip
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/${var.keyname}.pem")
  }

  provisioner "file" {
    source      = "./ansible.cfg"
    destination = "/home/ec2-user/ansible.cfg"
  }

  provisioner "file" {
    source      = "./inventory_aws_ec2.yml"
    destination = "/home/ec2-user/inventory_aws_ec2.yml"
  }

  provisioner "file" {
    source      = "~/.ssh/${var.keyname}.pem"
    destination = "/home/ec2-user/${var.keyname}.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname Ansible_control",
      "sudo yum install -y python3",
      "pip3 install --user ansible",
      "pip3 install --user boto3",
      "chmod 400 ${var.keyname}.pem"
    ]
  }
}
