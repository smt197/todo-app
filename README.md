# 🚀 MediShop Todo App — DevOps Documentation & Infrastructure

Une application Web Todo 3-tiers (Frontend React, Backend Express API, Base de données PostgreSQL) automatisée de bout en bout avec **Terraform**, **Ansible**, **Docker** et **GitHub Actions CI/CD** sur **AWS**.

---

## 🏗️ Architecture Globale (3-Tier sur AWS)

L'infrastructure AWS est découpée en **3 couches isolées (3-Tier Architecture)** respectant les meilleures pratiques de sécurité DevOps :

```text
               +-------------------------------------------------------+
               |                    INTERNET                           |
               +-------------------------------------------------------+
                                           |
                                  [Port 80 / 443 / 22]
                                           v
+-----------------------------------------------------------------------------------+
| VPC AWS (10.0.0.0/16)                                                             |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  | SOUS-RÉSEAU PUBLIC (10.0.1.0/24) — Zone us-east-1a                           |  |
|  |                                                                             |  |
|  |   [ Instance EC2 : FRONT (Bastion SSH + Reverse Proxy Nginx + Docker) ]      |  |
|  |   • IP Publique (FRONT_IP)                                                  |  |
|  |   • Conteneur Docker : todo-front (Port 3000:80)                             |  |
|  |   • NAT Gateway (permet aux sous-réseaux privés d'accéder à Internet)       |  |
|  +-----------------------------------------------------------------------------+  |
|                                     |                                             |
|                     +---------------+---------------+                             |
|                     | [Port 5000 (API)]             | [SSH Bastion ProxyCommand]  |
|                     v                               v                             |
|  +-----------------------------------------------------------------------------+  |
|  | SOUS-RÉSEAU PRIVÉ (10.0.2.0/24) — Zone us-east-1a                          |  |
|  |                                                                             |  |
|  |   [ Instance EC2 : BACK (API Express) ]                                     |  |
|  |   • IP Privée (BACK_IP - ex: 10.0.2.x)                                      |  |
|  |   • Conteneur Docker : todo-api (Port 5000:5000)                             |  |
|  |                                                                             |  |
|  |                     | [Port 5432 (PostgreSQL)]                              |  |
|  |                     v                                                       |  |
|  |   [ Instance EC2 : DB (PostgreSQL) ]                                        |  |
|  |   • IP Privée (DB_IP - ex: 10.0.2.y)                                        |  |
|  |   • Conteneur Docker : postgres-db (Port 5432:5432)                          |  |
|  |   • Volume persistant : /opt/postgres/data                                  |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```

---

## 📁 Structure du Projet

```text
todo-app/
├── .github/
│   └── workflows/
│       └── ci-cd.yml             # Pipeline GitHub Actions (Build, Push, Deploy & Rollback)
├── ansible/
│   ├── ansible.cfg               # Configuration Ansible (désactivation warnings, SSH)
│   ├── playbook.yml              # Playbook principal orchestrant les rôles
│   ├── inventory/
│   │   └── hosts.ini             # Inventaire généré dynamiquement par Terraform / CI-CD
│   └── roles/
│       ├── common/               # Rôle : Installation Docker & Docker Compose
│       │   └── tasks/main.yml
│       ├── front/                # Rôle : Nginx, Certbot SSL & Conteneur Frontend
│       │   ├── tasks/main.yml
│       │   ├── templates/nginx.conf.j2
│       │   └── handlers/main.yml
│       ├── back/                 # Rôle : Conteneur Backend API
│       │   └── tasks/main.yml
│       └── db/                   # Rôle : Conteneur PostgreSQL
│           └── tasks/main.yml
├── terraform/
│   ├── main.tf                   # Provisioning AWS (VPC, Subnets, Security Groups, EC2)
│   ├── variables.tf              # Déclaration des variables d'infrastructure
│   ├── outputs.tf                # Outputs (IPs publique & privées, IDs d'instances)
│   ├── terraform.tfvars.example  # Fichier exemple de variables local
│   └── templates/
│       └── inventory.tpl         # Template de l'inventaire Ansible
├── backend/                      # Application API Express Node.js
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── .gitignore
│   ├── package.json
│   └── src/
├── frontend/                     # Application Frontend React (Vite)
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── .gitignore
│   ├── package.json
│   └── src/
├── nginx/                        # Configuration Nginx locale pour dev/test
│   └── local.conf
├── docker-compose.yml            # Orchestration locale avec Docker Compose
├── .gitignore                    # Fichiers ignorés au niveau racine (Terraform, SSH, secrets)
└── README.md                     # Documentation du projet
```

---

## 🛠️ 1. Infrastructure as Code (Terraform)

Terraform est responsable du provisioning automatisé de toute l'infrastructure cloud AWS dans la région `us-east-1`.

### Composants créés dans `terraform/main.tf` :
1. **Réseau (VPC & Subnets)** :
   - **VPC** (`10.0.0.0/16`)
   - **Subnet Public** (`10.0.1.0/24`) : héberge l'instance Front et la **NAT Gateway**.
   - **Subnet Privé** (`10.0.2.0/24`) : héberge les instances Back et DB.
   - **Internet Gateway** : accès entrant/sortant pour le sous-réseau public.
   - **NAT Gateway + Elastic IP** : permet aux instances privées de télécharger des paquets (apt, docker pull) sans exposition directe à Internet.
2. **Groupes de Sécurité (Security Groups)** :
   - `front-sg` :
     - Port `22` (SSH) : ouvert pour le rebond SSH (Bastion), EC2 Instance Connect et CI/CD.
     - Ports `80` (HTTP) et `443` (HTTPS) : ouverts sur Internet (`0.0.0.0/0`).
   - `back-sg` :
     - Port `5000` (API) : accessible **uniquement depuis `front-sg`**.
     - Port `22` (SSH) : accessible **uniquement depuis `front-sg`** (Bastion).
   - `db-sg` :
     - Port `5432` (PostgreSQL) : accessible **uniquement depuis `back-sg`**.
     - Port `22` (SSH) : accessible **uniquement depuis `front-sg`** (Bastion).
3. **Instances EC2 & SSH** :
   - `aws_key_pair.deployer` : Clé SSH pour toutes les instances.
   - 3 instances EC2 Ubuntu (`t3.micro`) : `front`, `back`, `db`.

---

## ⚙️ 2. Gestion de Configuration & Déploiement (Ansible)

Ansible est configuré pour être **idempotent** (peut être exécuté plusieurs fois sans effets secondaires non désirés).

### Configuration (`ansible/ansible.cfg`)
Désactive les avertissements d'obsolescence (`deprecation_warnings = False`) et configure la vérification des clés hôtes SSH.

### Rôles Ansible (`ansible/roles/`)

| Rôle | Description | Fichiers / Tâches |
|---|---|---|
| **`common`** | S'applique à **toutes** les instances. Installe Docker Engine, Docker CLI et Docker Compose via le dépôt officiel Docker et la nouvelle méthode sécurisée GPG keyring (`docker.asc`). | `roles/common/tasks/main.yml` |
| **`db`** | S'applique à l'instance **DB**. Déploie le conteneur `postgres:16-alpine` avec un volume hôte persistant `/opt/postgres/data` et attend l'ouverture du port `5432`. | `roles/db/tasks/main.yml` |
| **`back`** | S'applique à l'instance **BACK**. Se connecte à Docker Hub, tire l'image API (`todo-api:latest`), et démarre le conteneur sur le port `5000` lié à la DB. | `roles/back/tasks/main.yml` |
| **`front`** | S'applique à l'instance **FRONT**. Installe Nginx, configure le Reverse Proxy vers le conteneur Front (port `3000`) et l'API (port `5000`), démarre le conteneur `todo-front`, et gère optionnellement le SSL Let's Encrypt via Certbot. | `roles/front/tasks/main.yml`<br>`templates/nginx.conf.j2` |

---

## 🔄 3. Pipeline CI/CD (GitHub Actions)

Le workflow `.github/workflows/ci-cd.yml` automatise la chaîne de livraison continue lors de chaque `git push` sur la branche `main`.

```text
[ Push main ]
     │
     ▼
┌──────────────────┐
│  detect-changes  │ (Détection des fichiers modifiés)
└────────┬─────────┘
         ├────────────────────────┐
         ▼                        ▼
┌──────────────────┐    ┌──────────────────┐
│  build-backend   │    │  build-frontend  │ (Build Docker & Push Docker Hub)
└────────┬─────────┘    └────────┬─────────┘
         └────────────────────────┤
                                  ▼
                         ┌──────────────────┐
                         │      deploy      │ (Connexion Bastion + Ansible Deploy)
                         └────────┬─────────┘
                                  │ (En cas d'échec)
                                  ▼
                         ┌──────────────────┐
                         │     rollback     │ (Restauration image précédente)
                         └──────────────────┘
```

### Étapes du Pipeline :

1. **`detect-changes`** :
   - Compare les fichiers modifiés avec le commit précédent (`git diff`).
   - Reconstruit intelligemment uniquement les modules impactés (Frontend, Backend, ou tout en cas de modification de configuration globale).
2. **`build-backend`** / **`build-frontend`** :
   - Utilise **Docker Buildx** avec du cache d'action GitHub (`type=gha`).
   - Tag les images avec `:latest` et avec le hash du commit `:${{ github.sha }}`.
   - Pousse les images sur **Docker Hub**.
3. **`deploy`** :
   - **Vérification automatique des secrets** requis.
   - Configuration de la clé SSH et test de connectivité vers le **Back** à travers le **Front** via SSH `ProxyCommand`.
   - Génération dynamique de l'inventaire Ansible `ansible/inventory/hosts.ini`.
   - Exécution de `ansible-playbook ansible/playbook.yml`.
4. **`rollback`** :
   - Se déclenche automatiquement en cas d'échec du job `deploy`.
   - Reconnecte par SSH aux instances et relance le conteneur Docker précédant via le dernier tag SHA.

---

## 🗝️ Secrets GitHub Requis

Pour faire fonctionner le pipeline CI/CD, configurez les secrets dans votre dépôt GitHub (**Settings > Secrets and variables > Actions**) :

| Secret | Description | Exemple |
|---|---|---|
| `DOCKER_USERNAME` | Identifiant Docker Hub | `monuser` |
| `DOCKER_PASSWORD` | Access Token / Mot de passe Docker Hub | `dckr_pat_xxx` |
| `SSH_PRIVATE_KEY` | Clé privée SSH (contenu de `~/.ssh/medishop-deployer`) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `FRONT_IP` | **IP Publique** de l'instance Front | `52.xx.xx.xx` |
| `BACK_IP` | **IP Privée** de l'instance Back | `10.0.2.x` |
| `DB_IP` | **IP Privée** de l'instance DB | `10.0.2.y` |
| `DB_USER` | Utilisateur PostgreSQL | `postgres` |
| `DB_PASSWORD` | Mot de passe PostgreSQL | `MotDePasseSecurise` |
| `DB_NAME` | Nom de la BDD PostgreSQL | `tododb` |
| `DOMAIN_NAME` | Nom de domaine (optionnel) | `todo.exemple.com` (ou laisser vide) |
| `CERTBOT_EMAIL` | Email pour Let's Encrypt (optionnel) | `admin@exemple.com` |

---

## 💻 4. Déploiement Local (Docker Compose)

Pour exécuter et tester l'ensemble de l'application localement sans passer par AWS :

```bash
# Démarrer tous les services (PostgreSQL, Backend API, Frontend React, Nginx Local)
docker compose up --build -d

# Accès :
# Frontend : http://localhost
# API Backend : http://localhost:5000/api/todos
# PostgreSQL : localhost:5432

# Arrêter les services
docker compose down
```

---

## 📋 Procédure de Premier Déploiement

1. **Provisionner l'infrastructure sur AWS** :
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Éditez terraform.tfvars avec votre IP admin
   terraform init
   terraform apply -auto-approve
   ```

2. **Récupérer les IPs générées** :
   ```bash
   terraform output
   ```

3. **Ajouter les secrets dans GitHub** (`FRONT_IP`, `BACK_IP`, `DB_IP`, `SSH_PRIVATE_KEY`, etc.).

4. **Pousser le code pour déclencher le déploiement** :
   ```bash
   git add .
   git commit -m "ci: declenchement du premier deploiement automatique"
   git push origin main
   ```
