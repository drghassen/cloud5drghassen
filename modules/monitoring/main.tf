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
      view   = "timeSeries"
      stat   = "Minimum"
      period = 60

      yAxis = {
        left = { min = 0, label = "Targets", showUnits = false }
      }

      annotations = {
        horizontal = [
          {
            value = var.minimum_healthy_hosts
            label = "Minimum healthy targets"
            color = "#ff7f0e"
          }
        ]
      }

      metrics = [
        ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.alb_dimension, "TargetGroup", local.target_group_dimension, { color = "#2ca02c", label = "Healthy" }],
        ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", local.alb_dimension, "TargetGroup", local.target_group_dimension, { stat = "Maximum", color = "#d62728", label = "Unhealthy" }]
      ]
    },
    {
      title  = "ALB - Requests and Errors"
      view   = "timeSeries"
      stat   = "Sum"
      period = 300

      yAxis = {
        left  = { min = 0, label = "Requests", showUnits = false }
        right = { min = 0, label = "5XX Errors", showUnits = false }
      }

      metrics = [
        ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_dimension, { color = "#1f77b4", label = "Requests", yAxis = "left" }],
        ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_dimension, { color = "#d62728", label = "ELB 5XX", yAxis = "right" }],
        ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_dimension, { color = "#ff7f0e", label = "Target 5XX", yAxis = "right" }]
      ]
    },
    {
      title  = "ALB - Response Time p95 (ms)"
      view   = "timeSeries"
      stat   = "p95"
      period = 60

      yAxis = {
        left = { min = 0, label = "Milliseconds", showUnits = false }
      }

      metrics = [
        ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_dimension, { id = "m1", visible = false }],
        [{ expression = "m1 * 1000", id = "e1", label = "p95 latency (ms)", color = "#9467bd" }]
      ]
    },
    {
      title  = "ASG - Capacity"
      view   = "timeSeries"
      stat   = "Average"
      period = 60

      yAxis = {
        left = { min = 0, label = "Instances", showUnits = false }
      }

      metrics = [
        ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#1f77b4", label = "Desired" }],
        ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#2ca02c", label = "In Service" }],
        ["AWS/AutoScaling", "GroupMinSize", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#7f7f7f", label = "Minimum" }],
        ["AWS/AutoScaling", "GroupMaxSize", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#d62728", label = "Maximum" }]
      ]
    },
    {
      title  = "ASG - Instance Lifecycle"
      view   = "timeSeries"
      stat   = "Average"
      period = 60

      yAxis = {
        left = { min = 0, label = "Instances", showUnits = false }
      }

      metrics = [
        ["AWS/AutoScaling", "GroupPendingInstances", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#ff7f0e", label = "Pending" }],
        ["AWS/AutoScaling", "GroupTerminatingInstances", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#d62728", label = "Terminating" }],
        ["AWS/AutoScaling", "GroupTotalInstances", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#1f77b4", label = "Total" }]
      ]
    },
    {
      title  = "EC2 - Average CPU"
      view   = "timeSeries"
      stat   = "Average"
      period = 300

      yAxis = {
        left = { min = 0, max = 100, label = "CPU (%)", showUnits = false }
      }

      annotations = {
        horizontal = [
          {
            value = 60
            label = "Scaling target"
            color = "#ff7f0e"
          },
          {
            value = local.alarms["ec2-cpu-high"].threshold
            label = "High CPU alarm"
            color = "#d62728"
          }
        ]
      }

      metrics = [
        ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.autoscaling_group_name, { color = "#1f77b4", label = "Average CPU" }]
      ]
    },
    {
      title  = "RDS - CPU Utilization"
      view   = "gauge"
      stat   = "Average"
      period = 60

      yAxis = {
        left = { min = 0, max = 100, showUnits = true }
      }

      metrics = [
        ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_identifier, { color = "#2ca02c", label = "RDS CPU" }]
      ]
    },
    {
      title  = "RDS - Free Storage (GiB)"
      view   = "timeSeries"
      stat   = "Minimum"
      period = 300

      yAxis = {
        left = { min = 0, label = "GiB", showUnits = false }
      }

      annotations = {
        horizontal = [
          {
            value = local.alarms["rds-storage-low"].threshold / 1073741824
            label = "Low storage alarm"
            color = "#d62728"
          }
        ]
      }

      metrics = [
        ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_instance_identifier, { id = "m1", visible = false }],
        [{ expression = "m1 / 1073741824", id = "e1", label = "Free storage (GiB)", color = "#2ca02c" }]
      ]
    },
    {
      title     = "RDS - Database Connections"
      view      = "singleValue"
      stat      = "Average"
      period    = 60
      sparkline = true

      metrics = [
        ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_identifier, { color = "#17becf", label = "Connections" }]
      ]
    }
  ]
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${var.name_prefix}-operations"

  dashboard_body = jsonencode({
    start          = "-PT3H"
    periodOverride = "inherit"

    widgets = [
      for index, widget in local.widgets : {
        type   = "metric"
        x      = (index % 3) * 8
        y      = floor(index / 3) * 6
        width  = 8
        height = 6

        properties = merge({
          region   = var.aws_region
          stacked  = false
          liveData = false
          timezone = "+0000"
        }, widget)
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
