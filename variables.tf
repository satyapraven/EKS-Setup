variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-ai"
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "node_group_name" {
  description = "EKS Node Group name"
  type        = string
  default     = "eks-ai-ng-public1"
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t4g.medium"
}

variable "node_desired_capacity" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_capacity" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_max_capacity" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "node_volume_size" {
  description = "Node volume size in GB"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "kube-ai"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "EKS-AI"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

variable "create_node_group" {
  description = "Whether to create the node group (set to false for initial cluster creation)"
  type        = bool
  default     = false
}