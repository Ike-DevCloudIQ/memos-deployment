output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.memos.repository_url
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}