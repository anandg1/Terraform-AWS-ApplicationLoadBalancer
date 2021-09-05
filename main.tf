resource "aws_vpc" "vpc01"{

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
          Name = "${var.project_name}-vpc"
 }

}

data "aws_availability_zones" "az" {

state = "available"

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc01.id
  tags = {
           Name = "${var.project_name}-igw"
  }
}
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

resource "aws_route_table_association" "public_asso1" {

  subnet_id      = aws_subnet.pub1.id
  route_table_id = aws_route_table.rt_public.id
}


resource "aws_route_table_association" "public_asso2" {

  subnet_id      = aws_subnet.pub2.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_security_group" "sglb" {
  name        = "sglb"
  description = "Allow 80,443,22"
  vpc_id      = aws_vpc.vpc01.id  
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

resource "aws_lb_listener" "listner" {
  
  load_balancer_arn = aws_lb.appln-lb.id
  port              = 80
  protocol          = "HTTP"
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

resource "aws_lb_listener_rule" "rule-1" {

  listener_arn = aws_lb_listener.listner.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1.arn
  }

  condition {
    host_header {
      values = ["version1.anandg.xyz"]
    }
  }
}

resource "aws_lb_listener_rule" "rule-2" {
    
  listener_arn = aws_lb_listener.listner.id
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-2.arn
  }

  condition {
    host_header {
      values = ["version2.anandg.xyz"]
    }
  }
}

resource "aws_launch_configuration" "lc-1" {
  image_id          = var.ami
  instance_type     = var.type
  security_groups   = [ aws_security_group.sglb.id ]
  user_data         = file("userdata1.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "lc-2" {
  image_id          = var.ami
  instance_type     = var.type
  security_groups   = [ aws_security_group.sglb.id ]
  user_data         = file("userdata2.sh")

  lifecycle {
    create_before_destroy = true
  }
}
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
    value = "Version-1"
  }

  lifecycle {
    create_before_destroy = true
  }
}


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
    value = "Version-2"
  }

  lifecycle {
    create_before_destroy = true
  }
}



