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
