provider "aws" {
region = "ap-south-1"
profile = "testing"
}
resource "aws_vpc" "my_new_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "myvpc"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_new_vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
tags = {
    Name = "subnet1public"
  }
}
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_new_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
tags = {
    Name = "subnet2private"
  }
}
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.my_new_vpc.id
tags = {
    Name = "my_internetgateway"
  }
}
resource "aws_eip" "tf_eip" {
  depends_on = [ aws_instance.wordpress_os , aws_instance.database , aws_instance.bastionhost ]
   vpc      = true
}
resource "aws_nat_gateway" "nat_gateway" {
  depends_on = [ aws_eip.tf_eip ]
  allocation_id = aws_eip.tf_eip.id
  subnet_id     = aws_subnet.public_subnet.id
tags = {
    Name = "my_Nat_gateway"
  }
}
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.my_new_vpc.id
route {
    
gateway_id = aws_internet_gateway.internet_gateway.id
    cidr_block = "0.0.0.0/0"
  }
tags = {
    Name = "my_rt2"
  }
}
resource "aws_route_table_association" "association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}
resource "aws_route_table" "nat_route_table" {
  depends_on = [ aws_nat_gateway.nat_gateway ]
  vpc_id = aws_vpc.my_new_vpc.id
  route {    
    gateway_id = aws_nat_gateway.nat_gateway.id
    cidr_block = "0.0.0.0/0"
  }
    tags = {
    Name = "my_nat_route_table"
  }
}
resource "aws_route_table_association" "association2" {
  depends_on = [ aws_route_table.nat_route_table ]
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.nat_route_table.id
}
resource "aws_security_group" "mysql_sg" {
  depends_on = [ aws_vpc.my_new_vpc ]
  name        = "mysql_sg"
  vpc_id      = aws_vpc.my_new_vpc.id
ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.wp_sg.id ]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "mysql_sg"
  }
}
resource "aws_security_group" "bh_sg" {
  depends_on = [ aws_vpc.my_new_vpc ]
  name        = "bh_sg"
  vpc_id      = aws_vpc.my_new_vpc.id
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0"]
  }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "bh_sg"
  }
}
resource "aws_security_group" "wp_sg" {
  depends_on = [ aws_vpc.my_new_vpc ]
  name        = "wpos_sg"
  vpc_id      = aws_vpc.my_new_vpc.id
ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0"]
  }
ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
ingress {
      description = "ICMP"  
      from_port = -1
      to_port = -1
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
    }
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "wpos_sg"
  }
}
resource "aws_instance" "wordpress_os" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [ aws_security_group.wp_sg.id ]
  key_name = "mykeys"
  tags = {
    Name = "WordPress"
    }
}
resource "aws_instance" "database" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private_subnet.id
  vpc_security_group_ids = [ aws_security_group.mysql_sg.id , aws_security_group.bh_sg.id ]
  key_name = "mykeys"
tags = {
    Name = "MySQL"
    }
}
resource "aws_instance" "bastionhost" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [ aws_security_group.bh_sg.id ]
  key_name = "mykeys"
  
    tags = {
    Name = "HostOS"
    }
}
