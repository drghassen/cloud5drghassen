locals {
  alb_dimension = trimprefix(
    split(":", var.alb_arn)[5],
    "loadbalancer/"
  )

  target_group_dimension = split(
    ":", var.target_group_arn
  )[5]

  alb_dimensions = {
    LoadBalancer = local.alb_dimension
  }

  target_dimensions = {
    LoadBalancer = local.alb_dimension
    TargetGroup  = local.target_group_dimension
  }

  asg_dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  rds_dimensions = {
    DBInstanceIdentifier = var.db_instance_identifier
  }

  alarms = {
    healthy-hosts-low = {
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HealthyHostCount"
      dimensions          = local.target_dimensions
      statistic           = "Minimum"
      comparison_operator = "LessThanThreshold"
      threshold           = var.minimum_healthy_hosts
      period              = 60
      evaluation_periods  = 3
      datapoints_to_alarm = 2
      treat_missing_data  = "breaching"
      description         = "Insufficient healthy application targets."
    }

    alb-5xx-high = {
      namespace           = "AWS/ApplicationELB"
      metric_name         = "HTTPCode_ELB_5XX_Count"
      dimensions          = local.alb_dimensions
      statistic           = "Sum"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      threshold           = 5
      period              = 300
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      treat_missing_data  = "notBreaching"
      description         = "Elevated load balancer server errors."
    }

    ec2-cpu-high = {
      namespace           = "AWS/EC2"
      metric_name         = "CPUUtilization"
      dimensions          = local.asg_dimensions
      statistic           = "Average"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 80
      period              = 300
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      treat_missing_data  = "missing"
      description         = "Sustained high average web CPU utilization."
    }

    rds-storage-low = {
      namespace           = "AWS/RDS"
      metric_name         = "FreeStorageSpace"
      dimensions          = local.rds_dimensions
      statistic           = "Minimum"
      comparison_operator = "LessThanThreshold"
      threshold           = 5 * 1024 * 1024 * 1024
      period              = 300
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      treat_missing_data  = "missing"
      description         = "RDS free storage below five GiB."
    }
  }

  widgets = [
    {
      title  = "ALB - Target Health"
      stat   = "Minimum"
      period = 60
      metrics = [
        ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.alb_dimension, "TargetGroup", local.target_group_dimension],
        ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", local.alb_dimension, "TargetGroup", local.target_group_dimension, { stat = "Maximum" }]
      ]
    },
    {
      title  = "ALB - Requests and Errors"
      stat   = "Sum"
      period = 60
      metrics = [
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_dimension],
        ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_dimension],
        ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_dimension]
      ]
    },
    {
      title  = "ALB - Response Time p95"
      stat   = "p95"
      period = 60
      metrics = [
        ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_dimension]
      ]
    },
    {
      title  = "ASG - Capacity"
      stat   = "Average"
      period = 60
      metrics = [
        ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.autoscaling_group_name],
        ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.autoscaling_group_name],
        ["AWS/AutoScaling", "GroupMinSize", "AutoScalingGroupName", var.autoscaling_group_name],
        ["AWS/AutoScaling", "GroupMaxSize", "AutoScalingGroupName", var.autoscaling_group_name]
      ]
    },
    {
      title  = "ASG - Instance Lifecycle"
      stat   = "Average"
      period = 60
      metrics = [
        ["AWS/AutoScaling", "GroupPendingInstances", "AutoScalingGroupName", var.autoscaling_group_name],
        ["AWS/AutoScaling", "GroupTerminatingInstances", "AutoScalingGroupName", var.autoscaling_group_name],
        ["AWS/AutoScaling", "GroupTotalInstances", "AutoScalingGroupName", var.autoscaling_group_name]
      ]
    },
    {
      title  = "EC2 - Average CPU"
      stat   = "Average"
      period = 300
      metrics = [
        ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.autoscaling_group_name]
      ]
    },
    {
      title  = "RDS - CPU Utilization"
      stat   = "Average"
      period = 60
      metrics = [
        ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier]
      ]
    },
    {
      title  = "RDS - Free Storage"
      stat   = "Minimum"
      period = 60
      metrics = [
        ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_instance_identifier]
      ]
    },
    {
      title  = "RDS - Database Connections"
      stat   = "Average"
      period = 60
      metrics = [
        ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_identifier]
      ]
    }
  ]
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.name_prefix}-operations"

  dashboard_body = jsonencode({
    periodOverride = "inherit"
    widgets = [
      for index, widget in local.widgets : {
        type   = "metric"
        x      = (index % 2) * 12
        y      = floor(index / 2) * 6
        width  = 12
        height = 6

        properties = {
          title   = widget.title
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = widget.period
          stat    = widget.stat
          metrics = widget.metrics
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  dimensions          = each.value.dimensions
  statistic           = each.value.statistic
  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  period              = each.value.period
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  treat_missing_data  = each.value.treat_missing_data

  actions_enabled = length(var.alarm_actions) > 0
  alarm_actions   = var.alarm_actions
  ok_actions      = var.alarm_actions

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}
