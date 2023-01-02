# VPC-EC2-Instance-Creation-WP-website-using-Terraform


++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Terraform AWS provider setup
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
[ec2-user@ip-172-31-6-147 ~]$ wget https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_amd64.zip
[ec2-user@ip-172-31-6-147 ~]$ unzip terraform_1.3.6_linux_amd64.zip
[ec2-user@ip-172-31-6-147 ~]$ sudo mv terraform /usr/local/bin/
[ec2-user@ip-172-31-6-147 ~]$ rm -rf terraform_1.3.6_linux_amd64.zip
[ec2-user@ip-172-31-6-147 ~]$ mkdir aws-vpc-project
[ec2-user@ip-172-31-6-147 ~]$ touch aws-vpc-project/{provider.tf,variables.tf,main.tf,output.tf,datasource.tf}
[ec2-user@ip-172-31-6-147 aws-vpc-project]$ ssh-keygen
[ec2-user@ip-172-31-6-147 aws-vpc-project]$ terraform init
~~~

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## datasource.tf
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat datasource.tf



data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_route53_zone" "mydomain" {
  name         = "sanjos.tech."
  private_zone = false
}
~~~
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## provider.tf
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat provider.tf


provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
  default_tags {
    tags = local.common_tags
  }
}
~~~

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## main.tf
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat main.tf

resource "aws_vpc" "vpc" {
  cidr_block           = var.sanjosnet
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.project}-${var.environment}"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project}-${var.environment}"
  }
}


resource "aws_subnet" "public" {
  count                   = local.subnets - 1
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.sanjosnet, 2, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project}-${var.environment}-public${count.index + 1}"
  }
}


resource "aws_subnet" "private" {
  count                   = local.subnets - 2
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.sanjosnet, 2, "${count.index + 2}")
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.project}-${var.environment}-private${count.index + 1}"
  }
}


resource "aws_eip" "nat" {
  vpc = true
  tags = {
    Name = "${var.project}-${var.environment}-natgw"
  }
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[1].id
  tags = {
    Name = "${var.project}-${var.environment}"
  }
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.project}-${var.environment}-public"
  }
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.project}-${var.environment}-private"
  }
}


resource "aws_route_table_association" "public" {
  count          = local.subnets - 1
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table_association" "private" {
  count          = local.subnets - 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


resource "aws_security_group" "web-traffic" {

  name_prefix = "${var.project}-${var.environment}-web-"
  description = "Allow http,https,ssh traffic only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-traffic.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "${var.project}-${var.environment}-web"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "bastion-traffic" {

  name_prefix = "${var.project}-${var.environment}-bastion-"
  description = "Allow ssh traffic only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "${var.project}-${var.environment}-bastion"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "db-traffic" {

  name_prefix = "${var.project}-${var.environment}-db-"
  description = "Allow mysql,ssh traffic only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web-traffic.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-traffic.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "${var.project}-${var.environment}-db"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_key_pair" "ssh_key" {

  key_name   = "${var.project}-${var.environment}"
  public_key = file("mykey.pub")
  tags = {
    Name = "${var.project}-${var.environment}"
  }
}


resource "aws_instance" "web" {

  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.0.id
  vpc_security_group_ids      = [aws_security_group.web-traffic.id]
  user_data                   = file("webserverdata.sh")
  user_data_replace_on_change = true
  depends_on                  = [aws_instance.db]
  tags = {
    "Name" = "${var.project}-${var.environment}-web"
  }
}


resource "aws_instance" "bastion" {

  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.1.id
  vpc_security_group_ids      = [aws_security_group.bastion-traffic.id]
  user_data                   = file("setup_bastion.sh")
  user_data_replace_on_change = true
  tags = {
    "Name" = "${var.project}-${var.environment}-bastion"
  }
}


resource "aws_instance" "db" {

  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  associate_public_ip_address = false
  subnet_id                   = aws_subnet.private.0.id
  vpc_security_group_ids      = [aws_security_group.db-traffic.id]
  user_data                   = file("databaseuserdata.sh")
  user_data_replace_on_change = true
  depends_on                  = [aws_nat_gateway.nat]

  tags = {
    "Name" = "${var.project}-${var.environment}-db"
  }
}


resource "aws_route53_zone" "private" {
  name = var.private_domain

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}


  resource "aws_route53_record" "database" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db.${var.private_domain}"
  type    = "A"
  ttl     = 5
  records = [aws_instance.db.private_ip]
}


resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name    = "wordpress.${var.wp_domain}"
  type    = "A"
  ttl     = 10
  records = [aws_instance.web.public_ip]
}
~~~


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## variables.tf
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat variables.tf



variable "region" {
  default = "us-east-2"
}
variable "access_key" {
  default = "AKIAWU45FUZLADAP2X7O"
}
variable "secret_key" {
  default = "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"
}
variable "project" {
  default = "zomato"
}
variable "environment" {
  default = "production"
}
variable "instance_ami" {
  default = "ami-0a606d8395a538502"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "sanjosnet" {
  default = "172.16.0.0/16"
}
variable "private_domain" {
  default = "sanjos.local"
}

variable "wp_domain" {
  default = "sanjos.tech"
}
locals {
  subnets = length(data.aws_availability_zones.available.names)
  common_tags = {
    "project"     = var.project
    "environment" = var.environment
  }
}
~~~

++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#### Database userdata
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat databaseuserdata.sh



#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment

sudo  systemctl restart sshd.service

sudo yum install -y mariadb-server
sudo systemctl restart mariadb.service
sudo systemctl enable mariadb.service

sudo mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('mysqlroot123') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF



sudo mysql -u root -pmysqlroot123  -e "create database blog;"

sudo mysql -u root -pmysqlroot123 -e "create user 'bloguser'@'%' identified by 'bloguser123';"

sudo mysql -u root -pmysqlroot123  -e "grant all privileges on blog.* to 'bloguser'@'%';"

sudo mysql -u root -pmysqlroot123 -e "flush privileges;"
~~~

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## webserver userdata
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat webserverdata.sh


#!/bin/bash
echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment
sudo service sshd restart
sudo yum install httpd -y
sudo amazon-linux-extras install php7.4
sudo systemctl restart httpd.service
sudo systemctl enable httpd.service
wget https://wordpress.org/wordpress-6.1.zip
unzip wordpress-6.1.zip

sudo cp -a wordpress/* /var/www/html/
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i 's/database_name_here/blog/g' /var/www/html/wp-config.php
sed -i 's/username_here/bloguser/g' /var/www/html/wp-config.php
sed -i 's/password_here/bloguser123/g' /var/www/html/wp-config.php
sed -i 's/localhost/db.sanjos.local/g' /var/www/html/wp-config.php
sudo chown -R apache.apache /var/www/html/*
sudo chown -R apache. /var/www/html/*
sudo systemctl restart httpd.service
~~~

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Bastion userdata
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ cat setup_bastion.sh


#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment

service sshd restart
~~~


+++++++++++++++++++++++++++++++++++++++++++++++++++++++
## list of files
+++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ ll


-rwxr-xr-x 1 ec2-user ec2-user  1047 Dec 31 16:00 databaseuserdata.sh
-rw-rw-r-- 1 ec2-user ec2-user   162 Dec 31 19:52 datasource.tf
-rw-rw-r-- 1 ec2-user ec2-user  7101 Dec 31 19:42 main.tf
-r-------- 1 ec2-user ec2-user  1675 Dec 30 14:55 mykey
-rw-r--r-- 1 ec2-user ec2-user   434 Dec 30 14:55 mykey.pub
-rw-rw-r-- 1 ec2-user ec2-user     0 Dec 30 14:52 output.tf
-rw-rw-r-- 1 ec2-user ec2-user   155 Dec 30 16:23 provider.tf
-rwxr-xr-x 1 ec2-user ec2-user   178 Dec 31 14:15 setup_bastion.sh
-rw-rw-r-- 1 ec2-user ec2-user 47697 Dec 31 19:57 terraform.tfstate
-rw-rw-r-- 1 ec2-user ec2-user   725 Dec 31 19:38 variables.tf
-rwxr-xr-x 1 ec2-user ec2-user   882 Dec 31 16:13 webserverdata.sh
~~~

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
### terraform state list
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

~~~
ec2-user@ip-172-31-6-147 ~/aws-vpc-secure-project-ec2_pending (default)$ terraform state list


data.aws_availability_zones.available
data.aws_route53_zone.mydomain
aws_eip.nat
aws_instance.bastion
aws_instance.db
aws_instance.web
aws_internet_gateway.igw
aws_key_pair.ssh_key
aws_nat_gateway.nat
aws_route53_record.database
aws_route53_record.website
aws_route53_zone.private
aws_route_table.private
aws_route_table.public
aws_route_table_association.private[0]
aws_route_table_association.public[0]
aws_route_table_association.public[1]
aws_security_group.bastion-traffic
aws_security_group.db-traffic
aws_security_group.web-traffic
aws_subnet.private[0]
aws_subnet.public[0]
aws_subnet.public[1]
aws_vpc.vpc
~~~
