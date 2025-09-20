# EKS Cluster Terraform Configuration - Staged Deployment

This Terraform configuration creates an Amazon EKS cluster with Graviton (ARM-based) instances in a staged approach, equivalent to using eksctl commands.

## Architecture

The configuration creates:

- **EKS Cluster**: Named `eks-ai` in `us-east-1` region
- **VPC**: Custom VPC with public and private subnets across 2 AZs
- **Node Groups**: Managed node group with Graviton instances (t4g.medium)
- **IAM Roles**: Proper IAM roles and policies for EKS and node groups
- **Security Groups**: Configured for cluster and node communication
- **OIDC Provider**: For IAM roles for service accounts
- **EC2 Key Pair**: For SSH access to nodes

## Staged Deployment Process

This configuration uses a two-stage deployment approach:

### Stage 1: Create EKS Cluster Only (30-40 minutes)
### Stage 2: Create Node Groups (10-15 minutes)

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (v1.0+)
3. **SSH Key Pair**: You need to have the public key file `kube-ai.pub` in the same directory

### Generate SSH Key Pair

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 2048 -f kube-ai

# This creates:
# - kube-ai (private key)
# - kube-ai.pub (public key - needed for Terraform)
```

## Deployment Steps

### Stage 1: Create EKS Cluster Only

1. **Clone and prepare:**
   ```bash
   cd terraform-eks-ai
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars** and ensure `create_node_group = false`:
   ```hcl
   create_node_group = false
   node_instance_type = "t4g.medium"  # Graviton instance
   ```

3. **Ensure you have the SSH public key:**
   ```bash
   # Make sure kube-ai.pub exists in this directory
   ls -la kube-ai.pub
   ```

4. **Initialize and deploy cluster:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. **Wait for cluster creation (30-40 minutes)**
   
6. **Configure kubectl to verify cluster:**
   ```bash
   aws eks --region us-east-1 update-kubeconfig --name eks-ai
   kubectl get svc
   ```

### Stage 2: Create Node Groups

7. **Update terraform.tfvars** to enable node group creation:
   ```hcl
   create_node_group = true
   ```

8. **Deploy node groups:**
   ```bash
   terraform plan
   terraform apply
   ```

9. **Wait for node group creation (10-15 minutes)**

10. **Verify the complete setup:**
    ```bash
    kubectl get nodes
    kubectl get pods -A
    ```

## Graviton Instance Configuration

This configuration uses **Graviton (ARM-based) instances** for better price-performance:

- **Instance Type**: `t4g.medium` (ARM-based Graviton2)
- **AMI Type**: `AL2_ARM_64` (Amazon Linux 2 for ARM)
- **Benefits**: Up to 40% better price performance compared to x86 instances

### Available Graviton Instance Types

You can modify `node_instance_type` in `terraform.tfvars` to use other Graviton instances:

- `t4g.nano`, `t4g.micro`, `t4g.small`, `t4g.medium`, `t4g.large`, `t4g.xlarge`, `t4g.2xlarge`
- `m6g.medium`, `m6g.large`, `m6g.xlarge`, `m6g.2xlarge`, `m6g.4xlarge`, etc.
- `c6g.medium`, `c6g.large`, `c6g.xlarge`, `c6g.2xlarge`, `c6g.4xlarge`, etc.

## File Structure

```
├── main.tf              # Provider configuration
├── variables.tf         # Variable definitions
├── vpc.tf              # VPC and networking resources
├── iam.tf              # IAM roles and policies
├── eks.tf              # EKS cluster and node groups
├── outputs.tf          # Output values
├── terraform.tfvars.example  # Example variables file
├── README.md           # This file
└── kube-ai.pub         # SSH public key (you need to provide this)
```

## Key Features

- **Staged deployment** to match eksctl workflow
- **Graviton instances** for better price-performance
- **Production-ready VPC** with public and private subnets
- **Managed Node Groups** with auto-scaling capabilities
- **Comprehensive IAM policies** matching eksctl permissions:
  - ECR full access
  - Auto Scaling access
  - External DNS access
  - ALB Ingress Controller access
  - App Mesh access
- **SSH access** to worker nodes
- **OIDC provider** for IAM roles for service accounts
- **Proper security groups** for cluster and node communication
- **CloudWatch logging** enabled for the cluster

## Customization

Key variables you can customize:

- `create_node_group`: Control staged deployment
- `cluster_name`: EKS cluster name
- `cluster_version`: Kubernetes version
- `node_instance_type`: Graviton instance type (t4g.medium, m6g.large, etc.)
- `node_desired_capacity`: Number of nodes
- `availability_zones`: AZs to deploy to
- `vpc_cidr`: VPC CIDR block

## Equivalent eksctl Commands

This staged Terraform configuration is equivalent to:

### Stage 1: Create Cluster
```bash
eksctl create cluster --name=eks-ai \
                      --region=us-east-1 \
                      --zones=us-east-1a,us-east-1b \
                      --without-nodegroup

# Associate OIDC provider
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster eks-ai \
    --approve
```

### Stage 2: Create Node Group
```bash
eksctl create nodegroup --cluster=eks-ai \
                        --region=us-east-1 \
                        --name=eks-ai-ng-public1 \
                        --node-type=t4g.medium \
                        --nodes=2 \
                        --nodes-min=2 \
                        --nodes-max=4 \
                        --node-volume-size=20 \
                        --ssh-access \
                        --ssh-public-key=kube-ai \
                        --managed \
                        --asg-access \
                        --external-dns-access \
                        --full-ecr-access \
                        --appmesh-access \
                        --alb-ingress-access
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Note:** This will delete all resources created by this configuration.

## Troubleshooting

1. **Missing public key**: Ensure `kube-ai.pub` exists in the project directory
2. **AWS credentials**: Verify AWS CLI is configured with proper permissions
3. **Region availability**: Some Graviton instance types may not be available in all AZs
4. **Quota limits**: Check AWS service quotas for EKS and EC2
5. **ARM compatibility**: Ensure your applications support ARM architecture

## Security Considerations

- Node groups are deployed in public subnets for demonstration purposes
- For production, consider using private subnets for node groups
- Review and adjust security group rules as needed
- Consider enabling envelope encryption for EKS secrets
- Graviton instances provide additional security benefits with dedicated hardware

## Monitoring Deployment Progress

### Stage 1 Progress
```bash
# Check cluster status
aws eks describe-cluster --region us-east-1 --name eks-ai --query 'cluster.status'

# Monitor CloudFormation stack (if using)
aws cloudformation describe-stacks --region us-east-1
```

### Stage 2 Progress
```bash
# Check node group status
aws eks describe-nodegroup --region us-east-1 --cluster-name eks-ai --nodegroup-name eks-ai-ng-public1 --query 'nodegroup.status'

# Check nodes
kubectl get nodes -o wide
```