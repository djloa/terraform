# Export ecr url 
output "ecr_url" {
  value = aws_ecr_repository.ecr_repo.url
}