# Copilot Instructions for eks-setup

## Project Overview
This repository provisions an Amazon EKS cluster using Terraform, with a focus on ARM-based (Graviton) instances and a staged deployment process. The architecture includes a custom VPC, managed node groups, IAM roles, OIDC provider, and SSH access to nodes.

## Key Files & Structure
- `main.tf`, `variables.tf`, `vpc.tf`, `iam.tf`, `eks.tf`, `outputs.tf`: Core Terraform modules for EKS, VPC, IAM, and outputs
- `terraform.tfvars`, `terraform.tfvars.example`: Main variable configuration (copy example to create your own)
- `stage1-cluster-only.tfvars`, `stage2-with-nodegroup.tfvars`: Example tfvars for staged deployment
- `deploy.sh`, `deploy-v1.sh`, `deploy-old.sh`, `destroy.sh`: Helper scripts for deployment and teardown
- `kube-ai.pub`: Required SSH public key for node access (must be present in project root)

## Staged Deployment Workflow
1. **Stage 1:** Deploy EKS cluster only (`create_node_group = false` in `terraform.tfvars`)
2. **Stage 2:** Deploy node groups (`create_node_group = true`)

Typical commands:
```bash
terraform init
terraform plan
terraform apply
# For cleanup:
terraform destroy
```

## Project Conventions
- **Graviton Instances:** Default node type is ARM-based (`t4g.medium`). Change `node_instance_type` in `terraform.tfvars` for other types.
- **SSH Key:** Always ensure `kube-ai.pub` is present before applying.
- **IAM/OIDC:** OIDC provider and IAM roles are provisioned for service accounts and add-ons.
- **Security Groups:** Configured for EKS and node communication; review for production use.
- **No hardcoded secrets:** All sensitive values should be set via variables or environment.

## Integration Points
- **AWS CLI:** Used for post-deployment cluster access (`aws eks update-kubeconfig ...`)
- **kubectl:** For cluster and node verification
- **eksctl:** Equivalent commands are documented in `README.md` for reference

## Customization
- Edit `terraform.tfvars` for cluster name, version, node type, AZs, and VPC CIDR
- Use provided example tfvars for staged deployment

## Troubleshooting & Tips
- If `kube-ai.pub` is missing, Terraform will fail
- Ensure AWS credentials are configured before running any scripts
- Monitor cluster/node group status with AWS CLI and `kubectl`
- For ARM compatibility, ensure workloads support ARM64

## Example: Stage 1 then Stage 2
1. Set `create_node_group = false` in `terraform.tfvars`, run `terraform apply`
2. Set `create_node_group = true`, run `terraform apply` again to add node groups

## References
- See `README.md` for full workflow, architecture, and troubleshooting details
- Key variables and patterns are documented in `variables.tf` and `terraform.tfvars.example`

---
For any unclear or missing conventions, review the latest `README.md` or ask for clarification.
