# ---------------------------
# GitHub OIDC Provider
# ---------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    # GitHub's OIDC root CA thumbprint (commonly used)
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

# ---------------------------
# IAM Role assumed by GitHub Actions
# ---------------------------
resource "aws_iam_role" "github_actions_infra_control" {
  name = "GitHubInfraControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          },
          StringLike = {
            # ✅ Restrict role usage to your repo
            # Example format: repo:my-org/my-repo:*
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

# ---------------------------
# Policy: ASG control + EC2 start/stop
# ---------------------------
resource "aws_iam_policy" "github_actions_infra_control" {
  name        = "GitHubInfraControllerPolicy"
  description = "Allows GitHub Actions to scale ASG and start/stop DB instance"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowASGControl",
        Effect = "Allow",
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowDBStartStop",
        Effect = "Allow",
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.github_actions_infra_control.name
  policy_arn = aws_iam_policy.github_actions_infra_control.arn
}
