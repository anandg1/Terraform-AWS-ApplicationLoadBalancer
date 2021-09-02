# Creating an Application Load Balancer using Terraform

[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)]()

# Description:
Let us see how to use a Terraform to build an AWS ALB Application load balancer.

> Terraform is a tool for building, changing, and versioning infrastructure safely and efficiently. Terraform can help with multi-cloud by having one workflow for all clouds. The infrastructure Terraform manages can be hosted on public clouds like Amazon Web Services, Microsoft Azure, and Google Cloud Platform, or on-prem in private clouds such as VMWare vSphere, OpenStack, or CloudStack. Terraform treats infrastructure as code (IaC) so you never have to worry about you infrastructure drifting away from its desired configuration

# Pre-requisites:

- AWS IAM account with the right policies attached for implementing the task. 
- Basic knowledge about AWS services.
- Terraform installed.

> Click here to [download](https://www.terraform.io/downloads.html) and  [install](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started) terraform.

Installation steps I followed:
```sh
wget https://releases.hashicorp.com/terraform/0.15.3/terraform_0.15.3_linux_amd64.zip
unzip terraform_0.15.3_linux_amd64.zip 
ls 
terraform  terraform_0.15.3_linux_amd64.zip    
mv terraform /usr/bin/
which terraform 
/usr/bin/terraform
```

# Steps:

## 1) creating the 'variables .tf' file

```sh
vi variable.tf
```
This file is used to declare the variables we are using in this project. The value of these variables are given later in terraform. tfvars file
> All the terrafom files must be created with .tf extension
```sh
variable "region" {}

variable "access_key"{}

variable "secret_key"{}

variable "project_name" {}

variable "vpc_cidr" {}

variable "subnet_bit" {}

variable "ami" {}

variable "type" {}

variable "asg_count" {}

```

## 2)  creating the 'provider .tf' file 

This file contains the provider configuration.
```sh
vi provider.tf
```
```sh
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
```

## 3) Creating the 'terraform. tfvars' file
The file is used to automatically load the variable definitions in it.
```sh
vi terraform.tfvars
```
```sh
region       = "Region-of-project"
project_name = "name-of-your-project"
vpc_cidr     = "your-cidr-block"
subnet_bit   = "x"
ami          = "ami-id"
type         = "type of instance"
access_key = "access-key-of-AWS-IAM-user"
secret_key = "secret-key-of-AWS-IAM-user"
asg_count  = "autoscaling count"
```
Here I'm going to try using the following values
```sh
region       = "us-east-2"
project_name = "my-project"
vpc_cidr     = "172.31.0.0/16"
subnet_bit   = "2"  
ami          = "ami-0443305dabd4be2bc"          
type         = "t2.micro"
access_key = "xxxxxxxxxxxxxxxx"
secret_key = "xxxxxxxxxxxxxxxxxxxxxx"
asg_count  = 2 
```
Now, enter the command given below to initialize a working directory containing Terraform configuration files. This is the first command that should be run after writing a new Terraform configuration.
```
terraform init
```
Now, we are going to set up the ALB.

# Application Load Balancer
Application Load Balancer operates at the request level (layer 7), routing traffic to targets (EC2 instances, containers, IP addresses, and Lambda functions) based on the content of the request. Ideal for advanced load balancing of HTTP and HTTPS traffic, Application Load Balancer provides advanced request routing targeted at delivery of modern application architectures, including microservices and container-based applications. Application Load Balancer simplifies and improves the security of your application, by ensuring that the latest SSL/TLS ciphers and protocols are used at all times.

### Working Of Application Load Balancer
Application Load Balancer consists of listeners and rules. When a client makes the request, the listener acknowledges it. The rules are guidelines that govern the routing of each client request once it’s heard by the listener. The rules consist of three components – Target group, Priority and Conditions. Target Groups consists of registered targets(servers where the traffic is to be routed). Each target group routes requests to one or more registered targets, such as EC2 instances, using the protocol and port number that you specify. So basically, when the listener gets the request, it goes through priority order to determine which rule to apply, analyzes the rules and based on condition, decides which target group gets the request.
> You can always add or remove targets from your load balancer as and when needed, without disrupting the overall flow of the requests to your application. ELB scales your load balancer dynamically, i.e. as traffic on your application changes over time keeping your application prepared for various situations.

![alt text](https://github.com/anandg1/Terraform-AWS-ApplicationLoadBalancer/blob/main/ALB.png)

## 4) Creating the 'main .tf' file

The main configuration file has the following contents:

> To create VPC
```sh
resource "aws_vpc" "vpc01"{

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
          Name = "${var.project_name}-vpc"
 }

}
```
> To list the AWS Availability Zones which can be accessed by an AWS account within the region configured.
```sh
data "aws_availability_zones" "az" {

state = "available"

}
```
> To create an Internet Gateway
```sh
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc01.id
  tags = {
           Name = "${var.project_name}-igw"
  }
}
```
> To create two public subnets
```sh
resource "aws_subnet" "pub1" {

  vpc_id = aws_vpc.vpc01.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 0)
  availability_zone = data.aws_availability_zones.az.names[0]
  tags = {
          Name = "${var.project_name}-pub1"
 }
}

resource "aws_subnet" "pub2" {

  vpc_id = aws_vpc.vpc01.id
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(var.vpc_cidr , var.subnet_bit , 1)
  availability_zone = data.aws_availability_zones.az.names[1]
  tags = {
          Name = "${var.project_name}-pub2"
 }
}
```

> Creating Public Route Table
```sh
resource "aws_route_table" "rt_public" {

  vpc_id= aws_vpc.vpc01.id
  route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
       }
        tags = {
                Name = "${var.project_name}-public-rt"
 }
}
```
> Creating Public Route Table Association
```sh
resource "aws_route_table_association" "public_asso1" {

  subnet_id      = aws_subnet.pub1.id
  route_table_id = aws_route_table.rt_public.id
}


resource "aws_route_table_association" "public_asso2" {

  subnet_id      = aws_subnet.pub2.id
  route_table_id = aws_route_table.rt_public.id
}
```
> Creating a security group for the load balancer
```sh
resource "aws_security_group" "sglb" {
  name        = "sglb"
  description = "Allow 80,443,22"
  vpc_id = aws_vpc.vpc01.id
  ingress {
    description      = "HTTPS"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
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
    Name = "sglb"
  }
    lifecycle {
    create_before_destroy = true
  }
}
```
> Creating Target Groups For the Application LoadBalancer
> I'm creating 2 target groups.

Target group 1
```sh
resource "aws_lb_target_group" "tg-1" {
  name     = "lb-tg-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc01.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    
  }

  lifecycle {
    create_before_destroy = true
  }
}
```
Target group 2
```sh
resource "aws_lb_target_group" "tg-2" {
  name     = "lb-tg-2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc01.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    
  }

  lifecycle {
    create_before_destroy = true
  }
}
```
> The create_before_destroy meta-argument changes this behavior so that the new replacement object is created first, and the prior object is destroyed after the replacement is created.

> Creating an Application LoadBalancer:
```sh
resource "aws_lb" "appln-lb" {
  name               = "appln-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sglb.id]
  subnets            = [aws_subnet.pub1.id,aws_subnet.pub2.id]
  enable_deletion_protection = false
  depends_on = [ aws_lb_target_group.tg-1]
  tags = {
     Name = "${var.project_name}-appln-lb"
   }
}

output "alb-endpoint" {
  value = aws_lb.appln-lb.dns_name
} 
```
Creating an http listener for the application load balancer with default action.
```sh
resource "aws_lb_listener" "listner" {
  
  load_balancer_arn = aws_lb.appln-lb.id
  port              = 80
  protocol          = "HTTP"
  
########################################
#Defualt action of the target group
#######################################

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = " Site Not Found"
      status_code  = "200"
   }
}
    
  depends_on = [  aws_lb.appln-lb ]
}
```
> Use the depends_on meta-argument to handle hidden resource or module dependencies that Terraform can't automatically infer.

> Forwarding the first hostname to target group-1 (eg: version1.anandg.xyz)
```sh
#########################################
#Forwarding rule 1
#########################################

resource "aws_lb_listener_rule" "rule-1" {

  listener_arn = aws_lb_listener.listner.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1.arn
  }

  condition {
    host_header {
      values = ["Hostname-1-"]
    }
  }
}
```

> Forwarding the second hostname to target group-2  (eg: version2.anandg.xyz)
```sh
resource "aws_lb_listener_rule" "rule-2" {
    
  listener_arn = aws_lb_listener.listner.id
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-2.arn
  }

  condition {
    host_header {
      values = ["Hostname-2-"]
    }
  }
}
```
> creating 2 Launch configurations with 2 different userdata (for example one has version 1 data and 2 has version 2 data)

> Lauch Configuration -1
```sh
resource "aws_launch_configuration" "lc-1" {
  image_id          = var.ami
  instance_type     = var.type
  security_groups   = [ aws_security_group.sglb.id ]
  user_data         = file("userdata1.sh")

  lifecycle {
    create_before_destroy = true
  }
}
```
> Lauch Configuration -2
```sh
resource "aws_launch_configuration" "lc-2" {
  image_id          = var.ami
  instance_type     = var.type
  security_groups   = [ aws_security_group.sglb.id ]
  user_data         = file("userdata2.sh")

  lifecycle {
    create_before_destroy = true
  }
}
```
> Creating the Auto Scaling Group-1 with Lauch configuration-1 with Target group-1
```sh
resource "aws_autoscaling_group" "asg-1" {

  launch_configuration    = aws_launch_configuration.lc-1.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier     = [aws_subnet.pub1.id,aws_subnet.pub2.id]
  target_group_arns       = [ aws_lb_target_group.tg-1.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

```
> Creating the Auto Scaling Group-2 with Lauch configuration-1 with Target group-2
```sh
resource "aws_autoscaling_group" "asg-2" {

  launch_configuration    = aws_launch_configuration.lc-2.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier     = [aws_subnet.pub1.id,aws_subnet.pub2.id]
  target_group_arns       = [ aws_lb_target_group.tg-2.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-2"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```
## 5) Creating 2 user datas files in the working directory for the launch configuration
```sh
vi userdata1.sh
```
```sh
#!/bin/bash


echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment
service sshd restart

echo "password123" | passwd root --stdin
sed  -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

yum install httpd php -y
systemctl enable httpd
systemctl restart httpd

cat <<EOF > /var/www/html/index.php
<?php
\$output = shell_exec('echo $HOSTNAME');
echo "<h1><center><pre>\$output</pre></center></h1>";
echo "<h1><center><pre>  Version1 </pre></center></h1>";
?>
EOF
```
```sh
vi userdata2.sh
```
```sh
#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment
service sshd restart

echo "password123" | passwd root --stdin
sed  -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

yum install httpd php -y
systemctl enable httpd
systemctl restart httpd

cat <<EOF > /var/www/html/index.php
<?php
\$output = shell_exec('echo $HOSTNAME');
echo "<h1><center><pre>\$output</pre></center></h1>";
echo "<h1><center><pre>  Version2 </pre></center></h1>";
?>
EOF
```

Now, inorder to validate the terraform files, run the following command:
```sh
terraform validate
```
Now, inorder to create and verify the execution plan, run the following command:
```sh
terraform plan
```
Now, let us executes the actions proposed in a Terraform plan by using the following command:
```sh
terraform apply
```

# Conclusion:

Succesfully deployed an AWS ALB Application load balancer using Terraform code.

