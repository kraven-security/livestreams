# storage-iam.tf
# S3 bucket for MISP attachments (keeps large blobs off slow shared volumes and out
# of the DB). MISP's S3 attachment feature is configured with explicit S3_ACCESS_KEY
# / S3_SECRET_KEY, so we provision a tightly-scoped IAM user for it.
#
# WHY KEYS AND NOT IRSA: MISP's built-in S3 attachment storage expects access/secret
# keys rather than the AWS default credential chain, so IRSA on the pod doesn't cover
# it cleanly today. We scope the user to this one bucket. If you confirm your build
# honours the default credential chain, swap this for an IRSA role on the `misp`
# ServiceAccount and drop the keys.

resource "aws_s3_bucket" "attachments" {
  bucket_prefix = "${var.cluster_name}-misp-attachments-"
  # Lab: allow `terraform destroy` to empty + delete the bucket. Production: refuse
  # to destroy a non-empty attachments bucket.
  force_destroy = !var.production
}

resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket                  = aws_s3_bucket.attachments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "attachments" {
  bucket = aws_s3_bucket.attachments.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_iam_user" "misp_s3" {
  name = "${var.cluster_name}-misp-s3"
}

resource "aws_iam_user_policy" "misp_s3" {
  name = "misp-s3-attachments"
  user = aws_iam_user.misp_s3.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.attachments.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.attachments.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_access_key" "misp_s3" {
  user = aws_iam_user.misp_s3.name
}
