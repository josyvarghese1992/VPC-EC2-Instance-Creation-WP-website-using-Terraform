# VPC-EC2-Instance-Creation-WP-website-using-Terraform

The goal of this project is to show users how to use Terraform to instal and host a WordPress application in AWS. Here is a list of all the Amazon EC2 instances that were utilised for this project. The database is managed by a separate Ec2 instance, while the frontend of the website CMS is housed on a separate Ec2 instance. Additionally, since the database was built within a private subnet, direct ssh access to this database server is prohibited. Only a third Ec2 instance known as a Bastion server will allow for public SSH access to either of these instances. The front-end server can handle HTTP and HTTPS connections from internet.

## Prerequisite

- IAM user with programmatic access and AmazonEc2FullAccess, AmazonVPCFullAccess  &  AmazonRoute53FullAccess
https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html

- Machine with latest version of git and terraform installed

## Terraform AWS provider setup

~~~
[ec2-user@ip-172-31-6-147 ~]$ wget https://releases.hashicorp.com/terraform/1.3.6/terraform_1.3.6_linux_amd64.zip
[ec2-user@ip-172-31-6-147 ~]$ unzip terraform_1.3.6_linux_amd64.zip
[ec2-user@ip-172-31-6-147 ~]$ sudo mv terraform /usr/local/bin/
[ec2-user@ip-172-31-6-147 ~]$ rm -rf terraform_1.3.6_linux_amd64.zip
[ec2-user@ip-172-31-6-147 ~]$ mkdir VPC-EC2-Instance-Creation-WP-website-using-Terraform
[ec2-user@ip-172-31-6-147 ~]$ touch VPC-EC2-Instance-Creation-WP-website-using-Terraform/{provider.tf,variables.tf,main.tf,output.tf,datasource.tf}
[ec2-user@ip-172-31-6-147 VPC-EC2-Instance-Creation-WP-website-using-Terraform]$ ssh-keygen
[ec2-user@ip-172-31-6-147 VPC-EC2-Instance-Creation-WP-website-using-Terraform]$ terraform init
~~~

Here establishing a VPC with CIDR 172.16.0.0/16 and hosting a WordPress website. 3 public and 1 private subnet are formed within the VPC. Additionally, by changing the map public IP on the launch parameter to true, public IP was made available for instances launched in the public subnet.Our database EC2 server is located in a private subnet inside the VPC, but the web server EC2 and bastion server EC2 instances were established in a public subnet. IGW and NATGW provide connectivity to the internet for the entire VPC. Here, we have public subnets that are connected to the IGW. The NAT gateway is connected to private subnets.

A created keypair connects every instance in the VPC. SSH-Keygen is used to create the Keypair, which is then saved as mykey and mykey.pub in the working directory. The file option is used to attach the generated keys to the resource aws key pair.

As I have already mentioned about the 3 instances, We are enabling HTTP and HTTPS traffic from everywhere and SSH access only from the bastion server traffic on the webserver EC2. This was done by creating a security group that is attached to the instance. The security group rules are used to permit MySQL access only from website and SSH access only from bastion server for the database server. All of the instances are running Amazon Linux's AMI (T2.Micro). We have made a separate SSH access rule by adding a security group because the bastion server can be accessed from anywhere. If your IP address is static, you can include that only in the security group rule of bastion server. Using the "depends on" parameter, we place a dependent on NAT gateway while configuring the backend instance. Therefore, the backend instance won't create until the NAT gateway is operational.

We are establishing a NAT gateway to facilitate internet traffic to private subnets, and in order to set up the NAT gateway, you must first purchase an EIP (elastic IP address).The VPC has two route tables, Private subnets are connected to private route, and all public subnets are connected to public-route table of the VPC  For the instances, we've defined three security groups. Additionally, we use two Route 53 zones within of our VPC. The private zone is configured to handle connections between the webserver and database server. Please be aware that DNS resolution for private subnet records only occurs inside the VPC. The domain URL is configured using the already-existing public zone, which is accessed through the data source.

## Use git clone to download the project files to your local system for execution

~~~
git clone https://github.com/josyvarghese1992/VPC-EC2-Instance-Creation-WP-website-using-Terraform.git
~~~

## Deploy the infrastructure using Terraform

~~~
$ cd  VPC-EC2-Instance-Creation-WP-website-using-Terraform
$ terraform validate
$ terraform plan
$ terraform apply
~~~

## Terraform state list

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
