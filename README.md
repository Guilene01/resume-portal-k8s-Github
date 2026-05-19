Resume Portal — Kubernetes on AWS EKS
A production-ready job application portal built with Flask, containerized with Docker, orchestrated with Kubernetes on AWS EKS, and fully automated with Terraform and GitHub Actions CI/CD.

Architecture
Internet
    ↓
Route 53 (gamela.shop)
    ↓
ALB Ingress Controller
    ↓                        ↓
gamela.shop              api.gamela.shop
    ↓                        ↓
Nginx Service            Flask Service
    ↓                        ↓
Nginx Pods               Flask Pods
(serves index.html)      (Python API)
                              ↓              ↓
                         RDS PostgreSQL  S3 + SES
                          (outside)      (outside)
What runs inside EKS
ComponentTypeReplicasFlask APIDeployment2 (auto-scales to 6)Nginx FrontendDeployment2ALB ControllerDaemonSetmanagedHPAAutoScalerper deployment
What runs outside EKS (managed AWS services)
ServicePurposeRDS PostgreSQLApplication databaseS3 (resumes)PDF resume storageS3 (frontend)Static file backupSESConfirmation emailsECRDocker image registryCloudFrontCDN for frontendRoute 53DNS managementACMSSL certificatesSecrets ManagerDatabase credentials

Project Structure
resume-portal-k8s/
│
├── .github/
│   └── workflows/
│       ├── terraform.yml      # Infrastructure pipeline
│       └── deploy.yml         # Application pipeline
│
├── terraform/                 # All AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── vpc/               # VPC, subnets, NAT gateways
│       ├── eks/               # EKS cluster, nodes, ALB controller
│       ├── rds/               # PostgreSQL database
│       ├── s3/                # S3 buckets, CloudFront
│       ├── iam/               # IRSA roles, GitHub OIDC
│       ├── iam_base/          # EKS cluster & node roles
│       └── ecr/               # Docker image repositories
│
├── k8s/                       # Kubernetes manifests
│   ├── flask/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   ├── nginx/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── ingress.yaml
│
├── app/                       # Flask backend
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
│
└── frontend/                  # Nginx frontend
    ├── index.html
    ├── nginx.conf
    └── Dockerfile

Prerequisites
Tools required
ToolVersionInstallTerraform>= 1.10.0terraform.iokubectl>= 1.32kubernetes.ioeksctl>= 0.205.0eksctl.ioAWS CLI>= 2.0aws.amazon.comDocker>= 24.0docker.comHelm>= 3.0helm.shGitanygit-scm.com
AWS requirements

AWS account with admin access
Domain registered in Route 53
SES verified email address
SES production access (for real users) or sandbox (for testing)

GitHub requirements

GitHub account
Repository created
OIDC configured (handled by Terraform automatically)


Quick Start
1. Clone the repository
bashgit clone https://github.com/Guilene01/resume-portal-k8s-Github.git
cd resume-portal-k8s-Github
2. Configure AWS credentials
bashaws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
3. Create Terraform state bucket
bashaws s3api create-bucket \
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
4. Update backend config
Edit terraform/versions.tf and update the bucket name:
hclbackend "s3" {
  bucket  = "your-terraform-state-bucket"
  key     = "resume-portal/terraform.tfstate"
  region  = "us-east-1"
  encrypt = true
}
5. Configure variables
bashcp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values
6. Deploy infrastructure
bashcd terraform
terraform init
terraform plan
terraform apply
7. Connect kubectl
bashaws eks update-kubeconfig --name resume-portal-cluster --region us-east-1
kubectl get nodes
8. Build and push Docker images
bash# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS \
  --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push Flask
cd app
docker build -t resume-portal-flask .
docker tag resume-portal-flask:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-flask:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-flask:latest

# Build and push Nginx
cd ../frontend
docker build -t resume-portal-nginx .
docker tag resume-portal-nginx:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-nginx:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/resume-portal-nginx:latest
9. Deploy to EKS
bashkubectl apply -f k8s/flask/deployment.yaml
kubectl apply -f k8s/flask/service.yaml
kubectl apply -f k8s/flask/hpa.yaml
kubectl apply -f k8s/nginx/deployment.yaml
kubectl apply -f k8s/nginx/service.yaml
kubectl apply -f k8s/ingress.yaml

# Verify everything is running
kubectl get pods
kubectl get services
kubectl get ingress

GitHub Actions CI/CD
How it works
terraform.yml — Infrastructure Pipeline
Triggers when files in terraform/ change.
Push to terraform/**
        ↓
  terraform init
  terraform fmt
  terraform validate
  terraform apply      ← creates AWS infrastructure
        ↓
  Wait 30 minutes      ← test your infrastructure
        ↓
  terraform destroy    ← saves money
On Pull Requests — runs terraform plan and posts results as a PR comment. No apply or destroy.
deploy.yml — Application Pipeline
Triggers when files in app/, frontend/, or k8s/ change.
Push to app/frontend/k8s/**
        ↓
  docker build flask   ← build Flask image
  docker build nginx   ← build Nginx image
  docker push ECR      ← push both to ECR
  kubectl apply        ← deploy to EKS
  kubectl set image    ← rolling update
        ↓
  Wait 30 minutes      ← test your app
        ↓
  kubectl delete       ← remove K8s resources
  terraform destroy    ← destroy all infrastructure
Setting up GitHub Actions
Step 1 — Add GitHub secrets
Go to your repo → Settings → Secrets and variables → Actions
No secrets needed! We use OIDC — GitHub authenticates with AWS using a temporary token. No stored credentials.
Step 2 — OIDC is configured automatically by Terraform
The modules/iam/main.tf creates:

GitHub OIDC provider in AWS
IAM role that GitHub Actions assumes
Policies for ECR, EKS, S3, and Terraform state

Step 3 — Push to main to trigger pipelines
bashgit add .
git commit -m "your change"
git push origin main
⚠️ First time OIDC setup note
If the GitHub OIDC provider already exists in your AWS account run this once before applying:
bashterraform import \
  module.iam.aws_iam_openid_connect_provider.github \
  arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

Terraform Modules
vpc — Networking

VPC with DNS support
2 public subnets (for ALB)
2 private subnets (for EKS nodes and RDS)
NAT Gateways for private subnet internet access
Security groups for EKS nodes and RDS

eks — Kubernetes Cluster

EKS cluster (Kubernetes 1.32)
Managed node group (t3.medium, 2-4 nodes)
OIDC provider for IRSA
ALB Ingress Controller via Helm
Auto-scaling configured

rds — Database

PostgreSQL 15 on db.t3.micro
Private subnet (not publicly accessible)
Encrypted storage
Automated backups (7 days)
Credentials stored in Secrets Manager

s3 — Storage & CDN

Resumes bucket (private, encrypted, versioned)
Frontend bucket (private, served via CloudFront)
CloudFront distribution with HTTPS
ACM certificate (DNS validated)
Route 53 records

iam — Permissions

Flask pod role (IRSA) — S3, SES, Secrets Manager access
GitHub Actions role (OIDC) — ECR, EKS, S3 access
GitHub OIDC provider

iam_base — EKS Base Roles

EKS cluster role
EKS node group role
Required AWS managed policy attachments

ecr — Docker Registry

Flask image repository
Nginx image repository
Lifecycle policy (keeps last 10 images)
Image scanning on push


Kubernetes Resources
Flask Deployment

2 replicas (auto-scales to 6)
Resource limits: 512Mi memory, 500m CPU
Liveness and readiness probes on /health
IRSA service account for AWS access

Nginx Deployment

2 replicas
Resource limits: 128Mi memory, 200m CPU
Serves index.html on port 80
Health check on /health

Ingress

AWS ALB (internet-facing)
HTTPS with ACM certificate
HTTP → HTTPS redirect
Two routing rules:

gamela.shop → Nginx service
api.gamela.shop → Flask service



HPA (Horizontal Pod Autoscaler)

Scale up when CPU > 70%
Scale up when memory > 80%
Min 2 replicas, Max 6 replicas


Cost Estimate
ResourceTypeCost/hourCost/dayEKS ClusterControl plane$0.10$2.40EKS Nodes2x t3.medium$0.10$2.40RDSdb.t3.micro$0.02$0.48NAT Gateways2x NAT$0.09$2.16ALBLoad Balancer$0.02$0.48Total~$0.33~$7.92

💡 The destroy job in GitHub Actions automatically tears down infrastructure after 30 minutes to minimize costs during testing.


Troubleshooting
Pods not starting
bashkubectl describe pod POD_NAME
kubectl logs POD_NAME
Ingress not getting an address
bash# Check ALB controller is running
kubectl get pods -n kube-system | grep aws-load-balancer

# Check ingress events
kubectl describe ingress resume-portal-ingress
Flask can't connect to RDS
bash# Check environment variables
kubectl exec -it POD_NAME -- env | grep DB

# Check secrets manager
aws secretsmanager get-secret-value \
  --secret-id resume-portal/db-credentials
SES email not sending
bash# Check Flask logs
kubectl logs POD_NAME | grep SES

# Verify SES identity
aws ses list-identities --region us-east-1
Terraform OIDC provider already exists
bashterraform import \
  module.iam.aws_iam_openid_connect_provider.github \
  arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
ECR repository not empty on destroy
Add force_delete = true to ECR repositories in modules/ecr/main.tf before running destroy.
CloudFront certificate timeout
The ACM certificate requires DNS validation. Go to ACM Console → click "Create records in Route 53" → wait 5 minutes for validation.

Security

No hardcoded credentials — all secrets in AWS Secrets Manager
OIDC authentication — no long-lived AWS credentials in GitHub
IRSA — pods only get the permissions they need
Private subnets — EKS nodes and RDS not publicly accessible
Encrypted storage — RDS and S3 encrypted at rest
HTTPS everywhere — HTTP redirects to HTTPS via ALB
Security groups — RDS only accepts connections from EKS nodes


Author
Built by Guilene — @Guilene01