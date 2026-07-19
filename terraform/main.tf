# ─────────────────────────────────────────────────────────────
# MediShop Todo App — Infrastructure AWS (3 couches)
# Architecture : Front (public) / Back (privé) / DB (privé)
# ─────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ═══════════════════════════════════════════════════════════════
# RÉSEAU (VPC, Subnets, Gateways, Route Tables)
# ═══════════════════════════════════════════════════════════════

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# --- Internet Gateway (accès Internet pour le sous-réseau public) ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# --- Sous-réseau public (Front) ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet"
    Project = var.project_name
  }
}

# --- Sous-réseau privé (Back + DB) ---
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name    = "${var.project_name}-private-subnet"
    Project = var.project_name
  }
}

# --- Route Table publique ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- NAT Gateway (permet aux instances privées d'accéder à Internet pour les mises à jour) ---
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.gw]
}

# --- Route Table privée (via NAT Gateway) ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ═══════════════════════════════════════════════════════════════
# SECURITY GROUPS — Ségrégation par couche
# ═══════════════════════════════════════════════════════════════

# --- Security Group : Front ---
# Internet → Front (HTTP/HTTPS) + Admin SSH
resource "aws_security_group" "front_sg" {
  name        = "${var.project_name}-front-sg"
  description = "Security group pour l'instance Front (reverse proxy Nginx)"
  vpc_id      = aws_vpc.main.id

  # SSH depuis l'IP de l'administrateur uniquement
  ingress {
    description = "SSH depuis l'admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # HTTP depuis Internet
  ingress {
    description = "HTTP depuis Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS depuis Internet
  ingress {
    description = "HTTPS depuis Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie — tout autorisé
  egress {
    description = "Tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-front-sg"
    Project = var.project_name
  }
}

# --- Security Group : Back ---
# Front → Back (port 5000, API) + SSH depuis Front uniquement (pour déploiement)
resource "aws_security_group" "back_sg" {
  name        = "${var.project_name}-back-sg"
  description = "Security group pour l'instance Back (API)"
  vpc_id      = aws_vpc.main.id

  # API depuis le Front uniquement (port 5000)
  ingress {
    description     = "API depuis le Front"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.front_sg.id]
  }

  # SSH depuis le Front (bastion) pour le déploiement
  ingress {
    description     = "SSH depuis le Front (bastion)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.front_sg.id]
  }

  # Sortie — tout autorisé (apt-get, docker pull, etc.)
  egress {
    description = "Tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-back-sg"
    Project = var.project_name
  }
}

# --- Security Group : DB ---
# Back → DB (port 5432, PostgreSQL) + SSH depuis Front (bastion)
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security group pour l'instance DB (PostgreSQL)"
  vpc_id      = aws_vpc.main.id

  # PostgreSQL depuis le Back uniquement (port 5432)
  ingress {
    description     = "PostgreSQL depuis le Back"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.back_sg.id]
  }

  # SSH depuis le Front (bastion) pour le déploiement
  ingress {
    description     = "SSH depuis le Front (bastion)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.front_sg.id]
  }

  # Sortie — tout autorisé
  egress {
    description = "Tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-db-sg"
    Project = var.project_name
  }
}

# ═══════════════════════════════════════════════════════════════
# KEY PAIR SSH
# ═══════════════════════════════════════════════════════════════

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

# ═══════════════════════════════════════════════════════════════
# INSTANCES EC2
# ═══════════════════════════════════════════════════════════════

# --- Instance Front (sous-réseau public) ---
resource "aws_instance" "front" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.front_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name    = "${var.project_name}-front"
    Role    = "front"
    Project = var.project_name
  }
}

# --- Instance Back (sous-réseau privé) ---
resource "aws_instance" "back" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.back_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name    = "${var.project_name}-back"
    Role    = "back"
    Project = var.project_name
  }
}

# --- Instance DB (sous-réseau privé) ---
resource "aws_instance" "db" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name    = "${var.project_name}-db"
    Role    = "db"
    Project = var.project_name
  }
}
