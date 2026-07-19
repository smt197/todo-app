# ─────────────────────────────────────────────────────────────
# Variables Terraform — MediShop Todo App
# Toutes les valeurs sont externalisées (pas de valeurs en dur)
# ─────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Région AWS"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR du sous-réseau public (Front)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR du sous-réseau privé (Back + DB)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Zone de disponibilité"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "Type d'instance EC2 (free tier)"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI Ubuntu (us-east-1)"
  type        = string
  default     = "ami-05cf1e9f73fbad2e2"
}

variable "key_name" {
  description = "Nom de la key pair SSH"
  type        = string
  default     = "medishop-deployer"
}

variable "public_key_path" {
  description = "Chemin vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/medishop-deployer.pub"
}

variable "admin_ip" {
  description = "IP de l'administrateur pour l'accès SSH (format: x.x.x.x/32)"
  type        = string
}

variable "project_name" {
  description = "Nom du projet (utilisé pour le tagging)"
  type        = string
  default     = "medishop-todo"
}

variable "domain_name" {
  description = "Nom de domaine pour l'application"
  type        = string
  default     = ""
}

variable "docker_username" {
  description = "Nom d'utilisateur Docker Hub"
  type        = string
}

variable "db_password" {
  description = "Mot de passe de la base de données PostgreSQL"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "Utilisateur de la base de données PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_name" {
  description = "Nom de la base de données PostgreSQL"
  type        = string
  default     = "tododb"
}
