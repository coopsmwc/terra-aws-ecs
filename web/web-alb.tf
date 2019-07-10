provider "aws" {
    region = "us-east-2"
}

resource "aws_lb" "web-alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-08dc63ee73ce47d4f"]
  subnets            = ["subnet-0bc07bde955773603", "subnet-0dda3f7d9f76c36d8", "subnet-0f2e2e82470305006"]

  enable_deletion_protection = false 

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "web-target-grp"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = "${aws_lb.web-alb.vpc_id}"
}

resource "aws_lb_target_group" "api" {
  name     = "api-target-grp"
  port     = 4001
  protocol = "HTTP"
  vpc_id   = "${aws_lb.web-alb.vpc_id}"
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = "${aws_lb.web-alb.arn}"
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.web.arn}"
  }
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = "${aws_lb.web-alb.arn}"
  port              = "4001"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.api.arn}"
  }
}
