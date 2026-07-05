# irsa-external-secrets.tf
# Scoped IRSA role for an `external-secrets-misp` ServiceAccount in the MISP
# namespace. It may ONLY read the two MISP secrets. The SecretStore in k8s
# references this SA; the annotation on the SA carries this role ARN.

data "aws_iam_policy_document" "eso_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:external-secrets-misp"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.cluster_name}-eso-misp"
  assume_role_policy = data.aws_iam_policy_document.eso_assume.json
}

resource "aws_iam_role_policy" "eso" {
  name = "read-misp-secrets"
  role = aws_iam_role.eso.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          aws_secretsmanager_secret.mysql.arn,
          aws_secretsmanager_secret.instance.arn
        ]
      }
    ]
  })
}

output "eso_irsa_role_arn" {
  description = "Annotate the external-secrets-misp ServiceAccount with this"
  value       = aws_iam_role.eso.arn
}
