# DevOps Learning Platform - EKS Deployment Guide

## Prerequisites
- AWS CLI installed and configured
- kubectl installed and configured
- eksctl installed
- Helm installed
- Docker installed

## Step 1: Clone the Repository and Organize Kubernetes Manifests

```bash
# Clone your repository (assuming you have one)
git clone https://github.com/your-org/devops-learning-platform.git
cd devops-learning-platform

# Create a k8s directory to store Kubernetes manifests
mkdir -p k8s
```

Copy all the YAML files for Kubernetes (namespace.yaml, secrets.yaml, backend.yaml, etc.) into this directory.

## Step 2: Create the EKS Cluster

```bash
eksctl create cluster \
  --name devops-learning \
  --region eu-west-1 \
  --version 1.27 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --managed
```

## Step 3: Create the RDS PostgreSQL Database

```bash
aws rds create-db-instance \
  --db-instance-identifier devops-learning-db \
  --db-instance-class db.t3.small \
  --engine postgres \
  --allocated-storage 20 \
  --master-username postgres \
  --master-user-password <strong-password> \
  --vpc-security-group-ids <security-group-id> \
  --db-subnet-group-name <your-subnet-group> \
  --backup-retention-period 7 \
  --multi-az
```

Note: Replace `<strong-password>`, `<security-group-id>`, and `<your-subnet-group>` with your actual values.

Make sure to:
1. Create a security group that allows inbound traffic on port 5432 from your EKS cluster's VPC
2. Create a DB subnet group that includes subnets in at least two availability zones

## Step 4: Build and Push Docker Images

```bash
# Log in to Amazon ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 163962798700.dkr.ecr.eu-west-1.amazonaws.com

# Create ECR repositories
aws ecr create-repository --repository-name devops-learning/frontend
aws ecr create-repository --repository-name devops-learning/backend

# Build and push images
docker build -t 163962798700.dkr.ecr.eu-west-1.amazonaws.com/devops-learning/frontend:latest --platform=linux/amd64 ./frontend
docker build -t 163962798700.dkr.ecr.eu-west-1.amazonaws.com/devops-learning/backend:latest --platform=linux/amd64  ./backend

docker push 163962798700.dkr.ecr.eu-west-1.amazonaws.com/devops-learning/frontend:latest
docker push 163962798700.dkr.ecr.eu-west-1.amazonaws.com/devops-learning/backend:latest
```

Replace `163962798700` with your AWS account ID.

## Step 5: Configure ALB Ingress Controller

The AWS Application Load Balancer (ALB) Ingress Controller is required for the ingress resource:

```bash
# Install the AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=devops-learning \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-west-2 \
  --set vpcId=<your-vpc-id> \
  --namespace kube-system
```

Replace `<your-vpc-id>` with your actual VPC ID.

## Step 6: Update Database Connection in ConfigMap

Edit the `secrets.yaml` file to update the database connection string:

```yaml
DATABASE_URL: "postgresql://postgres:<strong-password>@devops-learning-db.<your-db-endpoint>.us-west-2.rds.amazonaws.com:5432/devops_learning"
```

Replace `<strong-password>` and `<your-db-endpoint>` with your actual values.

## Step 7: Deploy the Application

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/database-service.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/horizontal-pod-autoscaler.yaml
kubectl apply -f k8s/ingress.yaml

# Verify deployments
kubectl get pods -n devops-learning
kubectl get svc -n devops-learning
kubectl get ingress -n devops-learning

kubectl logs -n devops-learning -l app=backend

kubectl logs -n devops-learning -l app=frontend

# access the app locally

kubectl port-forward -n devops-learning svc/backend 8000:8000

curl http://localhost:8000/api/topics

kubectl port-forward svc/frontend 8080:80 -n devops-learning


## to check the db connection for troubleshooting
kubectl run debug-pod --rm -it --image=postgres -- bash
PGPASSWORD=postgrespassword psql -h devops-learning-db.devops-learning.svc.cluster.local -U postgres -d devops_learning

# run query
SELECT COUNT(*) FROM topics;

```



## Step 8: Set Up Monitoring and Logging

Run the setup-monitoring.sh script:

```bash
chmod +x setup-monitoring.sh
./setup-monitoring.sh
```

## Step 9: Access the Application

After deployment, find the ALB URL:

```bash
kubectl get ingress -n devops-learning
```

This will give you the external address of the ALB. Use this address to access your application.

## Step 10: Set up DNS (Optional)

If you have a domain name, you can create a CNAME record pointing to the ALB address:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <your-hosted-zone-id> \
  --change-batch '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "devops-learning.yourdomain.com",
          "Type": "CNAME",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "<your-alb-address>"
            }
          ]
        }
      }
    ]
  }'
```

Replace `<your-hosted-zone-id>` and `<your-alb-address>` with your actual values.

## Troubleshooting

### Check Pod Logs
```bash
kubectl logs -f deploy/backend -n devops-learning
kubectl logs -f deploy/frontend -n devops-learning
```

### Check Pod Status
```bash
kubectl describe pod -l app=backend -n devops-learning
kubectl describe pod -l app=frontend -n devops-learning
```

### Restart Deployments
```bash
kubectl rollout restart deployment backend -n devops-learning
kubectl rollout restart deployment frontend -n devops-learning
```