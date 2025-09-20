#!/bin/bash

# EKS Cluster Staged Deployment Script
# This script automates the two-stage deployment process

set -e

echo "🚀 EKS Cluster Staged Deployment"
echo "================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# SSH key handling
if [ ! -f "kube-ai.pub" ]; then
    echo "⚠️ SSH public key 'kube-ai.pub' not found"

    # Check if AWS key pair already exists
    if aws ec2 describe-key-pairs --key-names kube-ai --query 'KeyPairs[*].KeyName' --output text 2>/dev/null | grep -q "kube-ai"; then
        echo "ℹ️ AWS key pair 'kube-ai' already exists."

        if [ -f "kube-ai" ]; then
            echo "🔑 Local private key found. Regenerating kube-ai.pub..."
            ssh-keygen -y -f kube-ai > kube-ai.pub
            echo "✅ Public key regenerated: kube-ai.pub"
        else
            echo "❌ Local private key 'kube-ai' not found."
            echo "   Please download it from AWS or remove the existing key pair and re-run."
            exit 1
        fi
    else
        echo "🔑 Creating new key pair in AWS named 'kube-ai'..."

        # Create new key pair in AWS
        aws ec2 create-key-pair \
            --key-name kube-ai \
            --query 'KeyMaterial' \
            --output text > kube-ai

        chmod 400 kube-ai
        echo "✅ Private key saved as kube-ai"

        # Generate corresponding .pub file
        ssh-keygen -y -f kube-ai > kube-ai.pub
        echo "✅ Public key saved as kube-ai.pub"
    fi
fi

echo "✅ All prerequisites met"

# Stage 1: Create EKS Cluster Only
echo ""
echo "🏗️  Stage 1: Creating EKS Cluster (30-40 minutes)"
echo "=================================================="

if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars from stage1 template..."
    cp stage1-cluster-only.tfvars terraform.tfvars
else
    echo "⚠️  terraform.tfvars already exists. Please ensure create_node_group = false"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "🔧 Initializing Terraform..."
terraform init

echo "📋 Planning cluster deployment..."
terraform plan -target=aws_eks_cluster.eks_cluster -target=aws_iam_openid_connect_provider.eks_oidc

echo "🚀 Creating EKS cluster..."
terraform apply -target=aws_eks_cluster.eks_cluster -target=aws_iam_openid_connect_provider.eks_oidc -auto-approve

echo "✅ EKS Cluster created successfully!"

# Configure kubectl
echo "🔧 Configuring kubectl..."
aws eks --region us-east-1 update-kubeconfig --name eks-ai

echo "🔍 Verifying cluster..."
kubectl get svc

echo ""
echo "✅ Stage 1 Complete!"
echo "==================="
echo "EKS Cluster 'eks-ai' has been created successfully."
echo ""

# Confirmation for Stage 2
read -p "🤔 Proceed with Stage 2 (Node Group creation)? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "⏸️  Deployment paused. To continue later:"
    echo "1. Update terraform.tfvars: set create_node_group = true"
    echo "2. Run: terraform apply"
    exit 0
fi

# Stage 2: Create Node Groups
echo ""
echo "🏗️  Stage 2: Creating Node Groups (10-15 minutes)"
echo "================================================="

echo "📝 Updating terraform.tfvars for node group creation..."
cp stage2-with-nodegroup.tfvars terraform.tfvars

echo "📋 Planning node group deployment..."
terraform plan

echo "🚀 Creating node groups..."
terraform apply -auto-approve

echo "✅ Node Groups created successfully!"

echo "🔍 Verifying complete setup..."
kubectl get nodes
kubectl get pods -A

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo "EKS Cluster 'eks-ai' with Graviton node groups is ready!"
echo ""
echo "Cluster Details:"
echo "- Name: eks-ai"
echo "- Region: us-east-1"
echo "- Node Type: t4g.medium (Graviton)"
echo "- Nodes: 2 (min: 2, max: 4)"
echo ""
echo "Next steps:"
echo "- Deploy your applications"
echo "- Configure monitoring and logging"
echo "- Set up ingress controllers if needed"
