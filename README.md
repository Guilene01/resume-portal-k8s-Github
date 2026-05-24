# Resume Portal — From EC2 to Kubernetes on AWS EKS

A production-ready job application portal that evolved from a simple EC2 deployment to a fully containerized, auto-scaling Kubernetes architecture on AWS EKS — automated end to end with Terraform and GitHub Actions CI/CD.

---

## Table of Contents

- [Project Story](#project-story)
- [Final Architecture](#final-architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Phase 1 — Manual Bootstrap](#phase-1--manual-bootstrap)
- [Phase 2 — Terraform Infrastructure](#phase-2--terraform-infrastructure)
- [Phase 3 — Docker Images](#phase-3--docker-images)
- [Phase 4 — Kubernetes Manifests](#phase-4--kubernetes-manifests)
- [Phase 5 — GitHub Actions CI/CD](#phase-5--github-actions-cicd)
- [Terraform Modules](#terraform-modules)
- [Kubernetes Resources](#kubernetes-resources)
- [GitHub Actions Pipelines](#github-actions-pipelines)
- [Cost Estimate](#cost-estimate)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

---

## Project Story

This project started as a simple resume submission portal running on a single EC2 instance with Flask, PostgreSQL on RDS, and file storage on S3. Along the way we fixed real production issues, hardened the security, and eventually migrated the entire application to Kubernetes on EKS — fully automated with Terraform and GitHub Actions.

### Journey

```
Stage 1 — EC2 + Flask + RDS + S3
  Single EC2 instance running Flask via Gunicorn
  RDS PostgreSQL for application data
  S3 for resume PDF storage
  SES for confirmation emails
  CloudFront + Route 53 for HTTPS and custom domain

Stage 2 — Issues fixed along the way
  Fixed JavaScript syntax error breaking form submission
  Fixed IAM permissions for EC2 to upload to S3
  Fixed SES sender email placeholder (your-email → real email)
  Fixed CloudFront routing to correctly reach Flask backend
  Moved to HTTPS everywhere

Stage 3 — Kubernetes on EKS
  Containerized Flask app with Docker
  Containerized Nginx frontend with Docker
  Pushed images to ECR
  Deployed to EKS with auto-scaling
  ALB Ingress Controller for traffic routing
  IRSA for secure pod-level AWS access
  Terraform for all infrastructure as code
  GitHub Actions + OIDC for full CI/CD automation
  Removed S3 frontend — Nginx serves index.html directly
  Full automation: Route 53, ACM cert, account ID injection
```

---

## Final Architecture

```
Internet
    ↓
Route 53
  resume.yourdomain.com  → ALB
  api.yourdomain.com     → ALB
    ↓
ALB Ingress Controller (one ALB, two rules)
    ↓                         ↓
resume.yourdomain.com     api.yourdomain.com
    ↓                         ↓
Nginx Service             Flask Service
    ↓                         ↓
Nginx Pods (x2)           Flask Pods (x2-6)
(serves index.html)       (Python API)
                               ↓              ↓
                          RDS PostgreSQL   S3 Resumes
                           (outside EKS)   (outside EKS)
                               ↓
                              SES
                           (outside EKS)
```

### What runs inside EKS

| Component | Type | Replicas |
|---|---|---|
| Flask API | Deployment | 2 (auto-scales to 6) |
| Nginx Frontend | Deployment | 2 |
| ALB Controller | Helm Release | managed |
| HPA | AutoScaler | per deployment |

### What runs outside EKS

| Service | Purpose |
|---|---|
| RDS PostgreSQL | Application database |
| S3 (resumes) | PDF resume storage |
| SES | Confirmation emails |
| ECR | Docker image registry |
| Route 53 | DNS management |
| ACM | SSL/TLS certificates |
| Secrets Manager | Database credentials |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML, CSS, JavaScript served by Nginx |
| Backend | Python Flask + Gunicorn |
| Database | PostgreSQL 15 on AWS RDS |
| Container Runtime | Docker |
| Container Orchestration | Kubernetes on AWS EKS 1.32 |
| Infrastructure as Code | Terraform |
| CI/CD | GitHub Actions |
| Image Registry | AWS ECR |
| DNS | AWS Route 53 |
| Email | AWS SES |
| Secrets | AWS Secrets Manager |
| Pod Auth | IRSA (IAM Roles for Service Accounts) |
| CI/CD Auth | OIDC (no stored credentials) |

---

## Project Structure

```
resume-portal-k8s/
│
├── .github/
│   └── workflows/
│       ├── terraform.yml      # Infrastructure pipeline
│       └── deploy.yml         # Application pipeline
│
├── terraform/
│   ├── main.tf                # Root module wiring all modules
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── versions.tf            # Provider versions + S3 backend
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/               # VPC, subnets, NAT gateways, SGs
│       ├── eks/               # EKS cluster, nodes, ALB controller
│       ├── rds/               # PostgreSQL + Secrets Manager
│       ├── s3/                # S3 resumes bucket, ACM cert, Route 53
│       ├── ses/               # SES email identity
│       ├── iam/               # Flask IRSA role, GitHub OIDC role
│       ├── iam_base/          # EKS cluster and node IAM roles
│       └── ecr/               # Docker image repositories
│
├── k8s/
│   ├── flask/
│   │   ├── deployment.yaml    # Flask pods + service account
│   │   ├── service.yaml       # ClusterIP service
│   │   └── hpa.yaml           # Horizontal pod autoscaler
│   ├── nginx/
│   │   ├── deployment.yaml    # Nginx pods
│   │   └── service.yaml       # ClusterIP service
│   └── ingress.yaml           # ALB ingress rules
│
├── app/
│   ├── app.py                 # Flask application
│   ├── requirements.txt       # Python dependencies
│   └── Dockerfile             # Flask container image
│
└── frontend/
    ├── index.html             # Resume submission form
    ├── nginx.conf             # Nginx server config
    └── Dockerfile             # Nginx container image
```

---

## Prerequisites

### Tools

| Tool | Version | Install |
|---|---|---|
| Terraform | >= 1.10.0 | [terraform.io/downloads](https://terraform.io/downloads) |
| kubectl | >= 1.32 | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools) |
| eksctl | >= 0.205.0 | [eksctl.io](https://eksctl.io) |
| AWS CLI | >= 2.0 | [aws.amazon.com/cli](https://aws.amazon.com/cli) |
| Docker Desktop | >= 24.0 | [docker.com](https://docker.com) |
| Helm | >= 3.0 | [helm.sh](https://helm.sh) |
| Git | any | [git-scm.com](https://git-scm.com) |

### AWS Requirements

- AWS account with admin or sufficient IAM permissions
- Domain registered and hosted in Route 53
- SES verified sender email address (handled by Terraform SES module)
- SES production access (or sandbox for testing with verified recipient emails only)

### GitHub Requirements

- GitHub account and repository
- GitHub OIDC provider and IAM role created manually (see Phase 1)
- GitHub secrets: `AWS_ROLE_ARN`, `AWS_ACCOUNT_ID`

---

## Phase 1 — Manual Bootstrap

Before anything can run in GitHub Actions, you need to create three things manually — the Terraform state bucket, the GitHub OIDC provider, and the GitHub Actions IAM role. This is a **one-time setup only**.

### Step 1 — Configure AWS credentials locally

```bash
aws configure
# AWS Access Key ID:     YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region:        us-east-1
# Default output format: json
```

### Step 2 — Create Terraform state bucket

```bash
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

Update `terraform/versions.tf` with your bucket name:
```hcl
backend "s3" {
  bucket  = "your-terraform-state-bucket"
  key     = "resume-portal/terraform.tfstate"
  region  = "us-east-1"
  encrypt = true
}
```

### Step 3 — Create GitHub OIDC provider manually

OIDC allows GitHub Actions to authenticate with AWS without storing credentials. It must exist before the pipeline can run.

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 4 — Create GitHub Actions IAM role manually

```bash
aws iam create-role \
  --role-name resume-portal-github-actions-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }]
  }'

aws iam attach-role-policy \
  --role-name resume-portal-github-actions-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

### Step 5 — Add GitHub repository secrets

Go to GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret Name | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::YOUR_ACCOUNT_ID:role/resume-portal-github-actions-role` |
| `AWS_ACCOUNT_ID` | `YOUR_ACCOUNT_ID` |

### Step 6 — Grant local user access to EKS

After the cluster is created by GitHub Actions, grant your local AWS identity kubectl access:

```bash
aws eks create-access-entry \
  --cluster-name resume-portal-cluster \
  --principal-arn arn:aws:iam::YOUR_ACCOUNT_ID:root \
  --region us-east-1

aws eks associate-access-policy \
  --cluster-name resume-portal-cluster \
  --principal-arn arn:aws:iam::YOUR_ACCOUNT_ID:root \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1
```

---

## Phase 2 — Terraform Infrastructure

### Step 1 — Configure variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:
```hcl
aws_region        = "us-east-1"
project_name      = "resume-portal"
environment       = "prod"
domain_name       = "yourdomain.com"
db_name           = "portal"
db_username       = "portaladmin"
db_instance_class = "db.t3.micro"
sender_email      = "your-verified-email@gmail.com"
```

### Step 2 — Initialize and deploy

```bash
cd terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

> Takes approximately 20-25 minutes. EKS and RDS are the slowest resources.

### Step 3 — Connect kubectl

```bash
aws eks update-kubeconfig \
  --name resume-portal-cluster \
  --region us-east-1

kubectl get nodes
```

---

## Phase 3 — Docker Images

### Login to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS \
  --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### Build and push Flask image

```bash
cd app
docker build -t resume-portal-flask .
docker tag resume-portal-flask:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-flask:latest
docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-flask:latest
```

### Build and push Nginx image

```bash
cd ../frontend
docker build -t resume-portal-nginx .
docker tag resume-portal-nginx:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-nginx:latest
docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-nginx:latest
```

---

## Phase 4 — Kubernetes Manifests

The pipeline handles this automatically. For manual deployment:

```bash
kubectl apply -f k8s/flask/deployment.yaml
kubectl apply -f k8s/flask/service.yaml
kubectl apply -f k8s/flask/hpa.yaml
kubectl apply -f k8s/nginx/deployment.yaml
kubectl apply -f k8s/nginx/service.yaml
kubectl apply -f k8s/ingress.yaml

kubectl get pods
kubectl get services
kubectl get ingress
```

---

## Phase 5 — GitHub Actions CI/CD

### How pipelines trigger

```
Change in terraform/**  →  terraform.yml runs
Change in app/**        →  deploy.yml runs
Change in frontend/**   →  deploy.yml runs
Change in k8s/**        →  deploy.yml runs
Pull Request opened     →  terraform plan comment on PR
```

### Trigger terraform pipeline

```bash
echo " " >> terraform/terraform.tfvars.example
git add terraform/terraform.tfvars.example
git commit -m "trigger: terraform pipeline"
git push origin main
```

### Trigger deploy pipeline

```bash
echo "# trigger" >> app/app.py
git add app/app.py
git commit -m "trigger: deploy pipeline"
git push origin main
```

---

## Terraform Modules

### `vpc` — Networking
- VPC (`10.0.0.0/16`) with DNS support
- 2 public subnets for ALB
- 2 private subnets for EKS nodes and RDS
- NAT Gateways for private subnet outbound internet
- Security group for EKS nodes
- Security group for RDS — allows port 5432 from EKS nodes SG **and** VPC CIDR

### `iam_base` — EKS Base Roles
- EKS cluster IAM role
- EKS node group IAM role with worker node, CNI, and ECR policies

### `eks` — Kubernetes Cluster
- EKS cluster (Kubernetes 1.32)
- Managed node group: `t3.medium`, min 1, max 4, desired 2
- OIDC provider for IRSA
- ALB Ingress Controller installed via Helm
- Root account access entry for local kubectl access

### `rds` — Database
- PostgreSQL 15 on `db.t3.micro`
- Private subnets, not publicly accessible
- Encrypted storage, 7-day backup retention
- Random password stored in AWS Secrets Manager

### `s3` — Storage and Certificates
- Resumes bucket: private, encrypted, versioned, force_destroy enabled
- ACM certificate for domain and wildcard (`*.yourdomain.com`)
- Route 53 DNS validation records for ACM

### `ses` — Email
- SES email identity for sender email
- Persists across terraform destroy/apply cycles
- ⚠️ After first apply check email inbox and click AWS verification link

### `iam` — Pod and CI/CD Permissions
- Flask pod IRSA role: S3, SES, Secrets Manager access
- Reads manually created GitHub OIDC provider as data source
- Reads manually created GitHub Actions role as data source

### `ecr` — Docker Registry
- `resume-portal-flask` repository
- `resume-portal-nginx` repository
- Lifecycle policy: keeps last 10 images
- `force_delete = true` for clean terraform destroy

---

## Kubernetes Resources

### Flask Deployment
```
replicas:         2
image:            ECR/resume-portal-flask:SHA
serviceAccount:   flask-sa (IRSA annotated)
resources:        256Mi-512Mi memory / 250m-500m CPU
probes:           GET /health :5000
env:              AWS_REGION, RESUME_BUCKET, DB_SECRET_NAME, SENDER_EMAIL
init:             Creates DB table on startup automatically
```

### Nginx Deployment
```
replicas:         2
image:            ECR/resume-portal-nginx:SHA
resources:        64Mi-128Mi memory / 100m-200m CPU
probes:           GET /health :80
serves:           index.html (resume submission form)
```

### Ingress
```
class:            alb
scheme:           internet-facing
target-type:      ip
ssl-redirect:     443
certificate:      ACM ARN (auto-updated by pipeline)

rules:
  resume.yourdomain.com  → nginx-service:80
  api.yourdomain.com     → flask-service:80
```

### HPA
```
target:           flask-deployment
min replicas:     2
max replicas:     6
scale up when:    CPU > 70% or memory > 80%
```

---

## GitHub Actions Pipelines

### `terraform.yml` — Infrastructure Pipeline

```
ON PUSH to terraform/**:
  ├── Configure AWS via OIDC
  ├── terraform init
  ├── terraform fmt (auto-fix)
  ├── terraform validate
  ├── terraform apply
  ├── Wait 90 minutes
  └── terraform destroy

ON PULL REQUEST:
  ├── terraform plan
  └── Post plan as PR comment
```

### `deploy.yml` — Application Pipeline

```
ON PUSH to app/** frontend/** k8s/**:
  JOB 1: build-and-deploy
  ├── Configure AWS via OIDC
  ├── Build & push Flask image to ECR
  ├── Build & push Nginx image to ECR
  ├── Update kubeconfig
  ├── Auto-update ACM cert ARN in ingress.yaml
  ├── Auto-inject AWS account ID in k8s manifests
  ├── kubectl apply all manifests
  ├── Rolling update Flask pods
  ├── Rolling update Nginx pods
  ├── Wait for ALB address (up to 5 min)
  ├── Auto-update Route 53:
  │     resume.yourdomain.com → ALB
  │     api.yourdomain.com    → ALB
  └── Verify pods/services/ingress/hpa

  JOB 2: destroy (after 30 minutes)
  ├── kubectl delete all K8s resources
  ├── Force delete any leftover ALBs
  ├── terraform destroy
  └── Confirm complete
```

### Why delete K8s resources before terraform destroy?

```
Wrong order:
  terraform destroy → VPC deletion fails
                    → ALB still exists (created by K8s ingress)
                    → Terraform doesn't know about it ❌

Correct order:
  kubectl delete ingress → AWS deletes the ALB
  sleep 120              → wait for ALB to fully terminate
  terraform destroy      → VPC deletes cleanly ✅
```

---

## Cost Estimate

| Resource | Type | $/hour | $/day |
|---|---|---|---|
| EKS Control Plane | Managed | $0.10 | $2.40 |
| EKS Nodes | 2x t3.medium | $0.10 | $2.40 |
| RDS | db.t3.micro | $0.02 | $0.48 |
| NAT Gateways | 2x | $0.09 | $2.16 |
| ALB | Load Balancer | $0.02 | $0.48 |
| **Total** | | **~$0.33** | **~$7.92** |

> The destroy job automatically tears down all infrastructure after 30 minutes to minimize costs during testing. ECR images survive the destroy and are reused on the next deployment.

---

## Troubleshooting

### Pods in CrashLoopBackOff
```bash
kubectl logs -l app=flask --tail=50
kubectl describe pods -l app=flask
```

### Ingress has no ADDRESS
```bash
kubectl get pods -n kube-system | grep aws-load-balancer
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20
kubectl describe ingress resume-portal-ingress
```
Most common cause: invalid certificate ARN. The pipeline auto-fixes this on each deploy.

### Flask cannot connect to RDS
```bash
# Test connectivity from pod
kubectl exec -it $(kubectl get pod -l app=flask \
  -o jsonpath='{.items[0].metadata.name}') -- python3 -c "
import socket
s = socket.create_connection(('YOUR_RDS_ENDPOINT', 5432), timeout=5)
print('Connected!')
s.close()
"
```
If timeout: check RDS security group allows VPC CIDR `10.0.0.0/16` on port 5432.

### kubectl forbidden error
```bash
aws eks associate-access-policy \
  --cluster-name resume-portal-cluster \
  --principal-arn arn:aws:iam::YOUR_ACCOUNT_ID:root \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1
```

### SES email not verified after apply
Check your email inbox for AWS verification email and click the link. The SES module creates the identity but AWS still requires email confirmation.

### terraform destroy fails — cannot delete VPC
```bash
# Delete ALB manually
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName,`k8s`)].LoadBalancerArn' \
  --output text --region us-east-1

aws elbv2 delete-load-balancer --load-balancer-arn YOUR_ARN --region us-east-1
sleep 90
terraform destroy -auto-approve
```

### Terraform state error after network interruption
```bash
terraform state push errored.tfstate
terraform apply -auto-approve
```

### GitHub Actions OIDC error on first run
The OIDC provider or IAM role may not exist. Follow Phase 1 steps 3 and 4 to create them manually before pushing.

---

## Security

| Practice | Implementation |
|---|---|
| No hardcoded credentials | All secrets in AWS Secrets Manager |
| No long-lived CI/CD keys | GitHub Actions uses OIDC temporary tokens |
| No account IDs in code | Injected at deploy time by pipeline |
| Least privilege pods | IRSA gives each pod only needed permissions |
| Private database | RDS in private subnet, no public endpoint |
| Private compute | EKS nodes in private subnets behind NAT |
| Encrypted storage | RDS and S3 encrypted at rest with AES256 |
| Encrypted transit | HTTPS everywhere, HTTP redirects to HTTPS |
| Network isolation | Security groups restrict RDS access |
| Image scanning | ECR scans every pushed image automatically |
| Random passwords | RDS password generated by Terraform |

---

## Author

Built by Guilene — [@Guilene01](https://github.com/Guilene01)

---

> This project was built step by step, fixing real production issues along the way — from a JavaScript typo crashing the form, to IAM permission errors, SES sandbox restrictions, CloudFront routing failures, RDS connectivity issues, and finally a full production-grade migration to Kubernetes. Every error made the architecture stronger.
```

### Step 3 — Validate and format

```bash
terraform fmt -recursive
terraform validate
```

### Step 4 — Plan and apply

```bash
terraform plan
terraform apply
```

This creates (in order):
1. VPC, subnets, NAT gateways, security groups
2. IAM roles for EKS cluster and nodes
3. EKS cluster and node group
4. ALB Ingress Controller via Helm
5. RDS PostgreSQL + Secrets Manager
6. S3 buckets + CloudFront + ACM certificate + Route 53 records
7. ECR repositories
8. IRSA role for Flask pods

> Takes approximately 20-25 minutes. EKS and RDS are the slowest.

### Step 5 — Connect kubectl

```bash
aws eks update-kubeconfig \
  --name resume-portal-cluster \
  --region us-east-1

kubectl get nodes
```

---

## Phase 3 — Docker Images

### Login to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS \
  --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### Build and push Flask image

```bash
cd app
docker build -t resume-portal-flask .
docker tag resume-portal-flask:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-flask:latest
docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-flask:latest
```

### Build and push Nginx image

```bash
cd ../frontend
docker build -t resume-portal-nginx .
docker tag resume-portal-nginx:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-nginx:latest
docker push \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-nginx:latest
```

### Verify images in ECR

```bash
aws ecr describe-images \
  --repository-name resume-portal-flask \
  --region us-east-1

aws ecr describe-images \
  --repository-name resume-portal-nginx \
  --region us-east-1
```

---

## Phase 4 — Kubernetes Manifests

### Deploy all resources

```bash
# Flask backend
kubectl apply -f k8s/flask/deployment.yaml
kubectl apply -f k8s/flask/service.yaml
kubectl apply -f k8s/flask/hpa.yaml

# Nginx frontend
kubectl apply -f k8s/nginx/deployment.yaml
kubectl apply -f k8s/nginx/service.yaml

# ALB Ingress
kubectl apply -f k8s/ingress.yaml
```

### Verify everything is running

```bash
# Nodes
kubectl get nodes

# Pods (wait for all Running)
kubectl get pods

# Services
kubectl get services

# Ingress (wait for ADDRESS to appear — takes 2-3 min)
kubectl get ingress

# Auto-scaler
kubectl get hpa

# ALB controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

---

## Phase 5 — GitHub Actions CI/CD

### Trigger infrastructure pipeline

Any change to `terraform/` triggers `terraform.yml`:

```bash
echo " " >> terraform/terraform.tfvars.example
git add terraform/terraform.tfvars.example
git commit -m "trigger: terraform pipeline"
git push origin main
```

### Trigger application pipeline

Any change to `app/`, `frontend/`, or `k8s/` triggers `deploy.yml`:

```bash
echo "# trigger" >> app/app.py
git add app/app.py
git commit -m "trigger: deploy pipeline"
git push origin main
```

### Test PR plan comment

```bash
git checkout -b feature/my-change
# make your terraform changes
git add .
git commit -m "feat: my infrastructure change"
git push origin feature/my-change
# Open Pull Request on GitHub
# Terraform plan will appear as a comment automatically
```

---

## Terraform Modules

### `vpc` — Networking
- VPC (`10.0.0.0/16`) with DNS hostnames and support enabled
- 2 public subnets tagged for ALB (`kubernetes.io/role/elb: 1`)
- 2 private subnets tagged for internal ALB (`kubernetes.io/role/internal-elb: 1`)
- 1 NAT Gateway per AZ for private subnet outbound internet
- Security group for EKS nodes (self-referencing ingress, all egress)
- Security group for RDS (port 5432 from EKS nodes SG only)

### `iam_base` — EKS Base Roles
Must exist before EKS cluster creation:
- EKS cluster IAM role with `AmazonEKSClusterPolicy`
- EKS node group IAM role with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`

### `eks` — Kubernetes Cluster
- EKS cluster (Kubernetes 1.32) with public and private endpoint access
- Managed node group: `t3.medium`, min 1, max 4, desired 2
- OIDC provider for IRSA (pod-level IAM access)
- ALB Ingress Controller installed via Helm chart `1.7.1`
- IAM role for ALB controller with required Load Balancer policies
- Root account access entry so local kubectl always works

### `rds` — Database
- PostgreSQL 15 on `db.t3.micro`
- Deployed in private subnets, not publicly accessible
- Encrypted storage with AES256
- Automated backups retained for 7 days
- Password randomly generated by Terraform (`random_password`)
- Full connection details stored in AWS Secrets Manager

### `s3` — Storage and CDN
- Resumes bucket: private, AES256 encrypted, versioning enabled
- Frontend bucket: private, accessible by CloudFront OAC only
- CloudFront distribution with HTTPS, IPv6, gzip compression
- ACM certificate for apex and www domain (DNS validated)
- Route 53 A alias records for `yourdomain.com` and `www.yourdomain.com`

### `iam` — Pod and CI/CD Permissions
- Flask pod IRSA role: `s3:PutObject/GetObject/DeleteObject`, `ses:SendEmail`, `secretsmanager:GetSecretValue`
- Reads manually created GitHub OIDC provider as a data source
- Reads manually created GitHub Actions role as a data source

### `ecr` — Docker Registry
- `resume-portal-flask` repository with image scanning on push
- `resume-portal-nginx` repository with image scanning on push
- Lifecycle policy: expire images when count exceeds 10
- `force_delete = true` for clean `terraform destroy`

---

## Kubernetes Resources

### Flask Deployment
```
replicas:         2
image:            ECR/resume-portal-flask:latest
serviceAccount:   flask-sa (IRSA annotated)
resources:
  requests:       256Mi memory / 250m CPU
  limits:         512Mi memory / 500m CPU
livenessProbe:    GET /health :5000 (after 10s, every 15s)
readinessProbe:   GET /health :5000 (after 5s, every 10s)
env:
  AWS_REGION, RESUME_BUCKET, DB_SECRET_NAME, SENDER_EMAIL
```

### Nginx Deployment
```
replicas:         2
image:            ECR/resume-portal-nginx:latest
resources:
  requests:       64Mi memory / 100m CPU
  limits:         128Mi memory / 200m CPU
livenessProbe:    GET /health :80 (after 5s, every 10s)
readinessProbe:   GET /health :80 (after 3s, every 5s)
```

### Ingress
```
class:            alb
scheme:           internet-facing
target-type:      ip
ssl-redirect:     443
certificate:      ACM ARN

rules:
  yourdomain.com      → nginx-service:80
  api.yourdomain.com  → flask-service:80
```

### HPA
```
target:           flask-deployment
min replicas:     2
max replicas:     6
scale up when:    CPU    > 70%
scale up when:    memory > 80%
```

---

## GitHub Actions Pipelines

### `terraform.yml` — Infrastructure Pipeline

```
ON PUSH to terraform/**
  ├── Checkout code
  ├── Configure AWS via OIDC (no stored credentials)
  ├── Setup Terraform 1.10.0
  ├── terraform init
  ├── terraform fmt -check
  ├── terraform validate
  ├── terraform apply -auto-approve
  ├── terraform output
  ├── Wait 30 minutes
  └── terraform destroy -auto-approve

ON PULL REQUEST to terraform/**
  ├── Checkout code
  ├── Configure AWS via OIDC
  ├── Setup Terraform 1.10.0
  ├── terraform init
  ├── terraform fmt -check
  ├── terraform validate
  ├── terraform plan -no-color
  └── Post plan as collapsible PR comment
```

### `deploy.yml` — Application Pipeline

```
ON PUSH to app/** frontend/** k8s/**
  JOB 1: build-and-deploy
  ├── Checkout code
  ├── Configure AWS via OIDC
  ├── Login to ECR
  ├── docker build flask → push :SHA and :latest
  ├── docker build nginx → push :SHA and :latest
  ├── aws eks update-kubeconfig
  ├── kubectl apply all manifests
  ├── kubectl set image flask → :SHA (rolling update)
  ├── kubectl rollout status --timeout=300s
  ├── Debug pods if rollout fails (describe + logs)
  ├── kubectl set image nginx → :SHA (rolling update)
  ├── kubectl rollout status --timeout=300s
  └── Verify pods / services / ingress / hpa

  JOB 2: destroy (needs: build-and-deploy)
  ├── Checkout code
  ├── Wait 30 minutes
  ├── Configure AWS via OIDC
  ├── aws eks update-kubeconfig
  ├── kubectl delete ingress (removes ALB)
  ├── kubectl delete hpa / services / deployments
  ├── sleep 60 (wait for ALB to fully delete)
  ├── Setup Terraform
  ├── terraform init
  ├── terraform destroy -auto-approve
  └── Confirm destroy complete
```

### Why delete K8s resources before terraform destroy?

```
Wrong order:
  terraform destroy → tries to delete VPC
                    → VPC deletion fails
                    → ALB still exists in VPC
                    → ALB was created by K8s ingress
                    → Terraform has no record of it ❌

Correct order:
  kubectl delete ingress → AWS deletes the ALB
  sleep 60               → wait for ALB to fully terminate
  terraform destroy      → VPC deletes cleanly ✅
```

---

## Cost Estimate

| Resource | Type | $/hour | $/day |
|---|---|---|---|
| EKS Control Plane | Managed | $0.10 | $2.40 |
| EKS Nodes | 2x t3.medium | $0.10 | $2.40 |
| RDS | db.t3.micro | $0.02 | $0.48 |
| NAT Gateways | 2x | $0.09 | $2.16 |
| ALB | Load Balancer | $0.02 | $0.48 |
| **Total** | | **~$0.33** | **~$7.92** |

> The destroy job automatically tears down all infrastructure after 30 minutes to minimize costs during testing. ECR images survive the destroy and are reused on the next deployment saving rebuild time.

---

## Troubleshooting

### Pods in CrashLoopBackOff
```bash
kubectl logs -l app=flask --tail=50
kubectl describe pods -l app=flask
```
Common causes: missing env variables, IRSA misconfigured, RDS unreachable.

### Ingress has no ADDRESS after several minutes
```bash
# Check ALB controller is running
kubectl get pods -n kube-system | grep aws-load-balancer

# Check ingress events
kubectl describe ingress resume-portal-ingress
```
Make sure `ingressClassName: alb` is set and not the deprecated `kubernetes.io/ingress.class` annotation.

### kubectl forbidden error
```bash
aws eks associate-access-policy \
  --cluster-name resume-portal-cluster \
  --principal-arn arn:aws:iam::YOUR_ACCOUNT_ID:root \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1
```

### Flask cannot connect to RDS
```bash
# Check secret exists and has correct values
aws secretsmanager get-secret-value \
  --secret-id resume-portal/db-credentials \
  --region us-east-1

# Check pod sees the environment variables
kubectl exec -it $(kubectl get pod -l app=flask \
  -o jsonpath='{.items[0].metadata.name}') -- env | grep -E "DB|SECRET"
```

### SES email not sending
```bash
kubectl logs -l app=flask | grep -i ses
aws ses list-identities --region us-east-1
```
In sandbox mode both sender and recipient emails must be verified. Request SES production access to remove this restriction.

### ECR repository not empty on destroy
Add `force_delete = true` to both ECR repositories in `modules/ecr/main.tf` then run destroy again.

### ACM certificate stuck in PENDING_VALIDATION
Go to ACM Console → your certificate → click **Create records in Route 53** → wait 5 minutes.

### terraform destroy fails — cannot delete VPC
The ALB from the K8s ingress was not deleted first. Clean it up manually:
```bash
kubectl delete ingress resume-portal-ingress --ignore-not-found
sleep 90
terraform destroy -auto-approve
```

### Terraform state error after network interruption
```bash
terraform state push errored.tfstate
terraform apply -auto-approve
```

### GitHub Actions OIDC error on first run
The OIDC provider or IAM role may not exist. Follow Phase 1 steps 3 and 4 to create them manually.

---

## Security

| Practice | Implementation |
|---|---|
| No hardcoded credentials | All secrets stored in AWS Secrets Manager |
| No long-lived CI/CD keys | GitHub Actions uses OIDC temporary tokens |
| Least privilege pods | IRSA gives each pod only the permissions it needs |
| Private database | RDS in private subnet, no public endpoint |
| Private compute | EKS nodes in private subnets behind NAT |
| Encrypted storage | RDS and S3 encrypted at rest with AES256 |
| Encrypted transit | HTTPS everywhere, HTTP auto-redirects to HTTPS |
| Network isolation | Security groups restrict RDS to EKS nodes only |
| Image scanning | ECR scans every pushed image automatically |
| Random passwords | RDS password generated by Terraform, never hardcoded |

---

## Author

Built by Guilene — [@Guilene01](https://github.com/Guilene01)

---

> This project was built step by step, fixing real issues along the way — from a JavaScript typo crashing the form, to IAM permission errors, SES sandbox restrictions, CloudFront routing failures, and eventually a full production-grade migration to Kubernetes. Every error made the architecture stronger.
