output "cluster_id" {
  value       = aws_eks_cluster.main.id
  description = "EKS cluster ID"
}

output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "EKS cluster endpoint"
}

output "cluster_ca_certificate" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "EKS cluster CA certificate"
}

output "cluster_oidc_issuer_url" {
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
  description = "EKS cluster OIDC issuer URL"
}

output "node_group_id" {
  value       = aws_eks_node_group.main.id
  description = "EKS node group ID"
}

output "pod_execution_role_arn" {
  value       = aws_iam_role.pod_execution_role.arn
  description = "ARN of IAM role for pod execution"
}

output "cluster_security_group_id" {
  value       = aws_security_group.eks_cluster.id
  description = "Security group ID for EKS cluster"
}

output "node_security_group_id" {
  value       = aws_security_group.eks_nodes.id
  description = "Security group ID for EKS nodes"
}
