resource "aws_s3_bucket" "scripts_bucket" {
  bucket = "my-scripts-bucket-98634"

  tags = {
    Name      = "my-scripts-bucket"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_block_public_access" {
  bucket = aws_s3_bucket.scripts_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}