resource "aws_instance" "k3s_master" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_master
  key_name               = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.k3s_master.id]
  subnet_id              = aws_subnet.public_a.id
  iam_instance_profile   = aws_iam_instance_profile.k8s_master_profile.name

  tags = {
    Name = "k3s-master"
  }

  user_data = <<-EOF
    #!/bin/bash

    TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
    PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
    PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

    if [ -z "$PRIVATE_IP" ] || [ -z "$PUBLIC_IP" ]; then
      echo "Failed to retrieve IP addresses from metadata. Exiting." >&2
      exit 1
    fi

    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --tls-san $${PUBLIC_IP} --tls-san $${PRIVATE_IP}" sh -

    TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
    while [ ! -s "$TOKEN_FILE" ]; do
      sleep 2
    done
    K3S_TOKEN=$(cat $TOKEN_FILE)

    KUBECONFIG_FILE="/etc/rancher/k3s/k3s.yaml"
    while [ ! -s "$KUBECONFIG_FILE" ]; do
      sleep 2
    done
    KUBE_SECRET=$(cat $KUBECONFIG_FILE)


    aws ssm put-parameter \
      --name "/k3s/kubeconfig" \
      --value "$KUBE_SECRET" \
      --type SecureString \
      --overwrite \
      --region ${var.aws_region}

    aws ssm put-parameter \
      --name "/k3s/token" \
      --value "$K3S_TOKEN" \
      --type SecureString \
      --overwrite \
      --region ${var.aws_region}

    echo "K3s installation complete."
  EOF
}

resource "aws_instance" "k3s_worker" {
  depends_on = [aws_instance.k3s_master]
  count      = 1

  ami                    = var.ami_id
  instance_type          = var.instance_type_worker
  key_name               = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.k3s_worker.id]
  subnet_id              = aws_subnet.public_a.id
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
  zone_id = data.aws_route53_zone.my_zone.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"
  ttl     = 300

  records = [aws_instance.k3s_master.public_ip]
}