output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "db_instance_id" {
  value = aws_instance.db.id
}

output "db_data_volume_id" {
  value = aws_ebs_volume.db_data.id
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_infra_control.arn
}
