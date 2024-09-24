output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.dns_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2_instance.id
}
