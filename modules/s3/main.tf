resource "aws_s3_bucket" "s3" {
  bucket = "${var.name}.${var.environment}.${var.domain}"
  acl    = "private"
  force_destroy = true

    lifecycle_rule {
        id      = "long-term"
        enabled = true

        transition {
            days          = 30
            storage_class = "STANDARD_IA"
        }
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }

  tags = {
    Name        = "Profile Picture bucket"
  }
}