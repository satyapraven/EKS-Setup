# Stage 2: Create Node Groups
# Copy this to terraform.tfvars after cluster is created

aws_region = "us-east-1"
cluster_name = "eks-ai"
cluster_version = "1.28"

vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

node_group_name = "eks-ai-ng-public1"
node_instance_type = "t4g.medium"  # Graviton instance
node_desired_capacity = 2
node_min_capacity = 2
node_max_capacity = 4
node_volume_size = 20

key_pair_name = "kube-ai"

# IMPORTANT: Set to true for Stage 2 (node group creation)
create_node_group = true

common_tags = {
  Project     = "EKS-AI"
  Environment = "dev"
  ManagedBy   = "terraform"
  Owner       = "DevOps-Team"
}