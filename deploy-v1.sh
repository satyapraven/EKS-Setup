#!/bin/bash

# EKS Cluster Staged Deployment Script (Linux/WSL/Mac)
# Automatically installs missing prerequisites

set -e

echo "🚀 EKS Cluster Staged Deployment"
echo "================================"

# Function to check and install missing tools
install_tool() {
    local tool=$1
    local install_cmd=$2

    if ! command -v "$tool" &> /dev/null; then
        echo "⚠️ $tool is not installed. Installing..."
        eval "$install_cmd"
        if ! command -v "$tool" &> /dev/null; then
            echo "❌ Failed to install $tool. Exiting."
            exit 1
        else
            echo "✅ $tool installed successfully."
        fi
    else
        echo "✅ $tool is already installed."
    fi
}

# Install Terraform
install_tool "terraform" "sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl unzip && \
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/hashicorp.list && \
sudo apt update && sudo apt install -y terraform"

# Install AWS CLI
install_tool "aws" "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install && rm -rf awscliv2.zip aws/"

# Install kubectl
install_tool "kubectl" "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"

echo "✅ All prerequisites are ready"

# ------------------------
# SSH key handling
# ------------------------
if [ ! -f "kube-ai.pub" ]; then
    echo "⚠️ SSH public key 'kube-ai.pub' not found"

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
        aws ec2 create-key-pair \
            --key-name kube-ai \
            --query 'KeyMaterial' \
            --output text > kube-ai

        chmod 400 kube-ai
        echo "✅ Private key saved as kube-ai"

        ssh-keygen -y -f kube-ai > kube-ai.pub
        echo "✅ Public key saved as kube-ai.pub"
    fi
fi

# ------------------------
# Stage 1: Create EKS Cluster
# ------------------------
echo ""
echo "🏗️  Stage 1: Creating EKS Cluster (30-40 minutes)"
echo "=================================================="

if [ ! -f "terraform.tfvars" ]; then
    cp stage1-cluster-only.tfvars terraform.tfvars
else
    echo "⚠️ terraform.tfvars already exists. Ensure create_node_group = false"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

terraform init
terraform plan -target=aws_eks_cluster.eks_cluster -target=aws_iam_openid_connect_provider.eks_oidc
terraform apply -target=aws_eks_cluster.eks_cluster -target=aws_iam_openid_connect_provider.eks_oidc -auto-approve

echo "✅ EKS Cluster created successfully!"

aws eks --region us-east-1 update-kubeconfig --name eks-ai
kubectl get svc

echo ""
echo "✅ Stage 1 Complete!"

# ------------------------
# Stage 2: Node Groups
# ------------------------
read -p "🤔 Proceed with Stage 2 (Node Group creation)? (y/N): " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "⏸️ Deployment paused. Set create_node_group = true and run terraform apply" && exit 0

cp stage2-with-nodegroup.tfvars terraform.tfvars
terraform plan
terraform apply -auto-approve

kubectl get nodes
kubectl get pods -A

echo ""
echo "🎉 Deployment Complete!"
