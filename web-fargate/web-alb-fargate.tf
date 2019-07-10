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
  port     = 80
  protocol = "HTTP"
  target_type = "ip"
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.web-alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-east-2:765932995230:certificate/fb2be921-9648-42f4-b727-47dd8070e23a"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.web.arn}"
  }
}

/*resource "aws_lb_listener" "api" {
  load_balancer_arn = "${aws_lb.web-alb.arn}"
  port              = "4001"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.api.arn}"
  }
}*/

data "aws_route53_zone" "example_dns" {
  name = "homedup.com."
}

resource "aws_route53_record" "example_alias" {
  zone_id = "${data.aws_route53_zone.example_dns.zone_id}"
  name    = "www.${data.aws_route53_zone.example_dns.name}"
  type    = "A"
  alias {
   name    = "${aws_lb.web-alb.dns_name}"
   zone_id = "${aws_lb.web-alb.zone_id}"
   evaluate_target_health = true
  }
}

resource "aws_ecs_cluster" "app" {
  name = "app-cluster"
}

resource "aws_ecs_service" "web" {
  name            = "web-service"
  launch_type = "FARGATE"
  cluster         = "${aws_ecs_cluster.app.id}"
  task_definition = "fargate-web:4"
  desired_count   = 2

  load_balancer {
    target_group_arn = "${aws_lb_target_group.web.arn}"
    container_name   = "fargate-web-ctr"
    container_port   = 80
  }
  
  network_configuration {
    subnets = ["subnet-0bc07bde955773603", "subnet-0dda3f7d9f76c36d8", "subnet-0f2e2e82470305006"]
    security_groups    = ["sg-030915769f04f480a"]
    assign_public_ip = true
  }
}

resource "aws_ecs_service" "api" {
  name            = "api-service"
  launch_type = "FARGATE"
  cluster         = "${aws_ecs_cluster.app.id}"
  task_definition = "fargate-api:1"
  desired_count   = 2

  network_configuration {
    subnets = ["subnet-0bc07bde955773603", "subnet-0dda3f7d9f76c36d8", "subnet-0f2e2e82470305006"]
    security_groups    = ["sg-0856f77f8afbf8451"]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.api.arn}"
  }
}

resource "aws_service_discovery_private_dns_namespace" "api" {
  name        = "app"
  description = "Fargate api service namespace"
  vpc         = "${aws_lb_target_group.web.vpc_id}"
}

resource "aws_service_discovery_service" "api" {
  name = "api-service"

  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.api.id}"

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
