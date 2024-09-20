// NOTE: var.launch_type = "EC2" if you want use following

resource "aws_ecs_service" "main" {
  count = var.launch_type == "EC2" ? 1 : 0

  name            = var.name
  cluster         = var.cluster_id
  launch_type     = var.launch_type
  task_definition = aws_ecs_task_definition.container[0].arn
  iam_role        = aws_iam_role.ecs_service[0].arn

  # Note: To prevent a race condition during service deletion,
  #       make sure to set depends_on to the related aws_iam_role_policy;
  #       otherwise, the policy may be destroyed too soon and the ECS service will then get stuck in the DRAINING state.
  depends_on = [aws_iam_role_policy.ecs_service]

  # As below is can be running in a service during a deployment
  desired_count                      = var.desired_count
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  ordered_placement_strategy {
    type  = var.placement_strategy_type
    field = var.placement_strategy_field
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = lookup(placement_constraints.value, "expression", null)
    }
  }

  dynamic "load_balancer" {
    for_each = var.load_balancers

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
      elb_name         = load_balancer.value.elb_name
    }
  }

  lifecycle {
    # INFO: In the future, we support that U can customize
    #       https://github.com/hashicorp/terraform/issues/3116
    ignore_changes = [
      desired_count,
      task_definition,
    ]
  }
}

resource "aws_ecs_task_definition" "container" {
  count = var.launch_type == "EC2" ? 1 : 0

  family                = var.container_family
  container_definitions = var.container_definitions
  # The following comment-out is no-support yet for BC-BREAK
  #network_mode            = "${var.network_mode}"
  #requires_compatibilities = ["${var.launch_type}"]
}

resource "aws_iam_role" "ecs_service" {
  count = var.launch_type == "EC2" ? 1 : 0

  name                  = "${var.name}-ecs-service-role"
  path                  = var.iam_path
  force_detach_policies = true
  assume_role_policy    = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy" "ecs_service" {
  count = var.launch_type == "EC2" ? 1 : 0

  name   = "${var.name}-ecs-service-policy"
  role   = aws_iam_role.ecs_service[0].name
  policy = var.iam_role_inline_policy
}

