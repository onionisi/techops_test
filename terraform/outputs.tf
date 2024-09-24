output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.lb_dns_name
}

output "ec2_instance_ids" {
  description = "EC2 instance IDs"
  value       = module.ec2_instance.id
}
