resource "aws_iam_role" "k8s_master_role" {
  name = "k8s-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.k8s_master_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k8s_master_profile" {
  name = "k8s-master-profile"
  role = aws_iam_role.k8s_master_role.name
}

resource "aws_iam_policy" "ec2_ecr_policy" {
  name        = "EC2_ECR_Policy"
  description = "Policy for EC2 to get ECR token "

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ec2_ecr_policy" {
  role       = aws_iam_role.k8s_master_role.name
  policy_arn = aws_iam_policy.ec2_ecr_policy.arn
}