############################################
# EKS Cluster Security Group
############################################
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

############################################
# EKS Cluster
############################################
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = var.common_tags
}

############################################
# EKS OIDC Identity Provider
############################################
data "tls_certificate" "eks_cluster_tls" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_tls.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-oidc"
  })
}

############################################
# Use existing EC2 Key Pair
############################################
data "aws_key_pair" "kube_ai_keypair" {
  key_name = var.key_pair_name
}

############################################
# Node Group Security Group
############################################
resource "aws_security_group" "eks_node_group_sg" {
  name_prefix = "${var.cluster_name}-node-group-sg"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description     = "Cluster API to node"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-node-group-sg"
  })
}

############################################
# EKS Node Group
############################################
resource "aws_eks_node_group" "eks_node_group" {
  count = var.create_node_group ? 1 : 0

  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  subnet_ids = aws_subnet.public_subnets[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = [var.node_instance_type]
  ami_type       = "AL2_ARM_64"

  scaling_config {
    desired_size = var.node_desired_capacity
    max_size     = var.node_max_capacity
    min_size     = var.node_min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  disk_size = var.node_volume_size

  remote_access {
    ec2_ssh_key               = data.aws_key_pair.kube_ai_keypair.key_name
    source_security_group_ids = [aws_security_group.eks_node_group_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
    aws_iam_role_policy_attachment.eks_ecr_full_access,
    aws_iam_role_policy_attachment.eks_autoscaling_policy,
    aws_iam_role_policy_attachment.eks_external_dns_policy,
    aws_iam_role_policy_attachment.eks_alb_ingress_policy,
  ]

  tags = merge(var.common_tags, {
    Name = var.node_group_name
  })
}
