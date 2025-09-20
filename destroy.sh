#!/bin/bash

# EKS Cluster Cleanup Script
# This will delete all resources created by deploy.sh:
# - EKS Cluster, Node Groups, IAM Roles (via Terraform destroy)
# - AWS EC2 key pair 'kube-ai'
# - Local SSH key files kube-ai and kube-ai.pub

set -e

echo "🔥 EKS Cluster Full Cleanup"
echo "=========================="

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

# Confirm before destruction
read -p "⚠️  This will permanently delete the EKS cluster and keys. Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "⏸️  Cleanup cancelled."
    exit 0
fi

# Step 1: Destroy Terraform resources
echo "🗑️  Destroying Terraform-managed resources..."
terraform destroy -auto-approve || {
    echo "⚠️  Terraform destroy failed. Please check resources manually."
    exit 1
}

# Step 2: Delete AWS key pair
echo "🗑️  Deleting AWS EC2 key pair 'kube-ai'..."
aws ec2 delete-key-pair --key-name kube-ai || echo "ℹ️  Key pair 'kube-ai' not found in AWS."

# Step 3: Delete local key files
echo "🗑️  Removing local key files..."
rm -f kube-ai kube-ai.pub

echo ""
echo "✅ Cleanup complete. All resources have been permanently deleted."
