data "aws_ec2_managed_prefix_list" "cloudfront" { # data is sort of a read-only request to AWS API for resources that already exist
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

#Note to self: Don't use inline SG rules such as ingress {} ingress{}, the second one will remove the first one.
# Use aws_security_group_rule instead
resource "aws_security_group" "alb" {
  name        = "${var.service_name}-alb-sg"
  description = "ALB SG - only reachable from CloudFront (+ optional dev access)"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "alb_cloudfront_http" { #accepts from all CF ips
  type              = "ingress"
  from_port         = 80  #range of ports, from 80 to 80 (that is, only 80)
  to_port           = 80
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront"
}

resource "aws_security_group_rule" "alb_dev_access" { # accepts dev ips
  for_each = toset(var.dev_access_cidrs)

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  security_group_id = aws_security_group.alb.id
  description       = "Temporary local-testing access"
}

resource "aws_security_group_rule" "alb_egress" { # allows all outbound traffic
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"  # all protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.service_name}-svc-sg"
  description = "Allow traffic from ALB only"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ecs_service_from_alb" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_service.id
  description               = "From ALB"
}

resource "aws_security_group_rule" "ecs_service_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_service.id
}
