variable "region" {
  default = "us-east-2"
}
variable "access_key" {
  default = "************************"
}
variable "secret_key" {
  default = "***************************"
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
​
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
