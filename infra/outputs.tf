output "master_instance_id" {
  description = "ID of the K3s master EC2 instance"
  value       = aws_instance.k3s_master.id
}