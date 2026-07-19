# ─────────────────────────────────────────────────────────────
# Outputs Terraform — IPs et informations de connexion
# ─────────────────────────────────────────────────────────────

output "front_public_ip" {
  description = "IP publique de l'instance Front"
  value       = aws_instance.front.public_ip
}

output "back_private_ip" {
  description = "IP privée de l'instance Back"
  value       = aws_instance.back.private_ip
}

output "db_private_ip" {
  description = "IP privée de l'instance DB"
  value       = aws_instance.db.private_ip
}

output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.main.id
}

output "front_instance_id" {
  description = "ID de l'instance Front"
  value       = aws_instance.front.id
}

output "back_instance_id" {
  description = "ID de l'instance Back"
  value       = aws_instance.back.id
}

output "db_instance_id" {
  description = "ID de l'instance DB"
  value       = aws_instance.db.id
}

output "nat_gateway_ip" {
  description = "IP publique du NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# Génération automatique de l'inventaire Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    front_public_ip = aws_instance.front.public_ip
    back_private_ip = aws_instance.back.private_ip
    db_private_ip   = aws_instance.db.private_ip
    ssh_key_path    = var.public_key_path != "" ? replace(var.public_key_path, ".pub", "") : "~/.ssh/medishop-deployer"
    front_ip        = aws_instance.front.public_ip
  })
  filename = "${path.module}/../ansible/inventory/hosts.ini"

  depends_on = [
    aws_instance.front,
    aws_instance.back,
    aws_instance.db
  ]
}
