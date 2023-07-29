terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#configure the AWS provider
provider "aws" { 
  access_key = "AKIAZQYAYXLWTM6K4Z34"
  secret_key = "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"
  region     = "ap-southeast-2"
}

# resource "aws_key_pair" "deployer" {
#   key_name   = "deployerkey"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDAWZYU9N9+GDHPJJfcgXTB+Isc6CY5xOGb9Fmz1o3tIwqLS9+w817hrR/+BBA+s7Vss4bHhIifItD8TeFV+MX68viV9epVpnwHBhO23Avdc+EVcJUxVzxARWyDGR1Vg/rRBg3qBZf17H7cc5hXJ6Xs38GvxstfftI8AojL+ENZfZNaxtksbY1EO+PW5S84UeN2Mx36bIprhFYsJC0GoFIA+kdxo7eP+1ilp4waYUeNGMvbJEY53F2JQos9z43DwWa0REGSX94K5LKnsAKjI/HG8t2hF2x7LIhsabl505zkLNEguPofh1NmM8mUL0y64eVeLbATx8OsUQ3DuPxaWDgZ mea\dt965fz@IN3336125W1"
# }
resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "my_subnet"
  }
}
resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my_vpc.id
    tags ={
        Name = "my-igw"
    }
}

resource "aws_route_table" "my-public-crt" {
    vpc_id = aws_vpc.my_vpc.id
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0" 
        //CRT uses this IGW to reach internet
        gateway_id = aws_internet_gateway.my_igw.id
    }
    
    tags = {
        Name = "my-public-crt"
    }
}
resource "aws_route_table_association" "my-crta-public-subnet-1"{
    subnet_id = aws_subnet.my_subnet.id
    route_table_id = aws_route_table.my-public-crt.id
}

resource "aws_security_group" "ssh-allowed" {
    vpc_id = aws_vpc.my_vpc.id
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        // This means, all ip address are allowed to ssh ! 
        // Do not do it in the production. 
        // Put your office or home address in it!
        cidr_blocks = ["0.0.0.0/0"]
    }
    //If you do not add this rule, you can not reach the NGIX  
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "ssh-allowed"
    }
}


resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "generated_key" {
  key_name   = "demo"
  public_key = tls_private_key.demo_key.public_key_openssh
}
resource "local_file" "tf_key" {
  content = tls_private_key.demo_key.private_key_pem
  filename = "demo"
}
resource "aws_instance" "ubuntu" {
ami           = "ami-0d02292614a3b0df1"
instance_type = "t2.micro"
subnet_id = aws_subnet.my_subnet.id
key_name      = aws_key_pair.generated_key.key_name
security_groups = [aws_security_group.ssh-allowed.id]

user_data     = <<EOF
 #!/bin/bash
 sudo apt update
 sudo apt install openjdk-11-jdk -y
 wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
 sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
 sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5BA31D57EF5975CA
 sudo apt update
 sudo apt install jenkins
 sudo systemctl start jenkins

 EOF

 tags = {
   Name = "amazon-linux"
 }
}