resource "aws_instance" "k3s_master" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_master
  vpc_security_group_ids = [aws_security_group.k3s_master.id]
  subnet_id              = aws_subnet.private_a.id
  iam_instance_profile   = aws_iam_instance_profile.k8s_master_profile.name

  tags = {
    Name = "k3s-master"
  }

  user_data = templatefile("../scripts/master_user_data.sh", {
    AWS_REGION = var.aws_region
  })
}

resource "aws_instance" "k3s_worker" {
  depends_on = [aws_instance.k3s_master]
  count      = 1

  ami                    = var.ami_id
  instance_type          = var.instance_type_worker
  vpc_security_group_ids = [aws_security_group.k3s_worker.id]
  subnet_id              = aws_subnet.private_b.id
  iam_instance_profile   = aws_iam_instance_profile.k8s_worker_profile.name

  tags = {
    Name = "k3s-worker-${count.index}"
  }

  user_data = <<-EOF
    #!/bin/bash

    while true; do
      K3S_TOKEN=$(aws ssm get-parameter \
        --name "/k3s/token" \
        --with-decryption \
        --query "Parameter.Value" \
        --output text)

      if [ -n "$K3S_TOKEN" ]; then
        echo "Token found. Beginning k3s installation."
        break
      fi

      echo "Token not ready yet, retrying in 5s..."
      sleep 5
    done

    curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.private_ip}:6443 K3S_TOKEN=$K3S_TOKEN sh -
    aws ssm delete-parameter --name /k3s/token
  EOF
}

data "aws_route53_zone" "my_zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "www" {
  depends_on = [aws_lb.cluster_alb]
  zone_id = data.aws_route53_zone.my_zone.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.cluster_alb.dns_name
    zone_id                = aws_lb.cluster_alb.zone_id
    evaluate_target_health = true
  }
}