output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "database_securitygroup_id" {
    value = aws_security_group.database.id
}

output "application_securitygroup_id" {
    value = aws_security_group.application.id
}