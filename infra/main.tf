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

    echo "K3s installation complete."
  EOF
}

resource "aws_instance" "k3s_worker" {
  depends_on = [aws_instance.k3s_master, null_resource.get_k3s_token]
  count      = 1

  ami                    = var.ami_id
  instance_type          = var.instance_type_worker
  key_name               = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.k3s_worker.id]
  subnet_id              = aws_subnet.public_a.id

  tags = {
    Name = "k3s-worker-${count.index}"
  }

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k3s_master.private_ip}:6443 K3S_TOKEN=${chomp(file("k3s_token.txt"))} sh -
  EOF
}

resource "null_resource" "get_k3s_token" {
  triggers = {
    master_ip = aws_instance.k3s_master.public_ip
    instance_id = aws_instance.k3s_master.id
  }

  provisioner "local-exec" {
    command = <<-EOF
      TOKEN_FILE="k3s_token.txt"

      for _ in {1..5}; do
        COMMAND_ID=$(aws ssm send-command \
          --targets "Key=instanceIds,Values=${self.triggers.instance_id}" \
          --document-name "AWS-RunShellScript" \
          --comment "Get K3s token" \
          --parameters '{"commands":["sudo cat /var/lib/rancher/k3s/server/node-token"]}' \
          --query "Command.CommandId" \
          --output text)

        aws ssm get-command-invocation \
          --command-id "$COMMAND_ID" \
          --instance-id "${self.triggers.instance_id}" \
          --query "StandardOutputContent" \
          --output text > "$TOKEN_FILE"

        if grep -q '[^[:space:]]' "$TOKEN_FILE"; then
          echo "Token successfully saved to $TOKEN_FILE"
          exit 0
        fi

        sleep 5
      done

      echo "Error: TOKEN not found."
      exit 1
    EOF
  }
}

resource "null_resource" "kubeconfig_download" {
  depends_on = [null_resource.get_k3s_token, aws_instance.k3s_worker]

  triggers = {
    always_run = timestamp()
    instance_id = aws_instance.k3s_master.id
    master_ip   = aws_instance.k3s_master.public_ip
  }

  provisioner "local-exec" {
    command = <<-EOF
      KUBECONFIG_FILE="kubeconfig"

      for _ in {1..5}; do
        COMMAND_ID=$(aws ssm send-command \
          --targets "Key=instanceIds,Values=${self.triggers.instance_id}" \
          --document-name "AWS-RunShellScript" \
          --comment "Download kubeconfig" \
          --parameters '{"commands":["sudo cat /etc/rancher/k3s/k3s.yaml"]}' \
          --query "Command.CommandId" \
          --output text)

        aws ssm get-command-invocation \
          --command-id "$COMMAND_ID" \
          --instance-id "${self.triggers.instance_id}" \
          --query "StandardOutputContent" \
          --output text > $KUBECONFIG_FILE


        if grep -q '[^[:space:]]' "$KUBECONFIG_FILE"; then
          echo "Kubeconfig saved to $KUBECONFIG_FILE"
          exit 0
        fi

        echo "Kubeconfig not ready yet, retrying in 5 seconds..."
        sleep 5
      done

      echo "Error: KUBECONFIG not found."
      exit 1
    EOF
  }
}


resource "null_resource" "install_master" {
  depends_on = [null_resource.kubeconfig_download, aws_instance.k3s_worker]

  triggers = {
    always_run = timestamp()
    master_ip = aws_instance.k3s_master.public_ip
    instance_id = aws_instance.k3s_master.id
  }

  provisioner "local-exec" {
    command = <<EOT

      COMMAND_ID=$(aws ssm send-command \
        --targets "Key=instanceIds,Values=${self.triggers.instance_id}" \
        --document-name "AWS-RunShellScript" \
        --comment "Create ECR secret in K3s" \
        --parameters '{"commands":["SECRET_PASS=$(aws ecr get-login-password) && kubectl delete secret ecr-cred --ignore-not-found && kubectl create secret docker-registry ecr-cred --docker-server=038462790533.dkr.ecr.eu-central-1.amazonaws.com --docker-username=AWS --docker-password=$SECRET_PASS && kubectl get secret ecr-cred -n default"]}' \
        --query "Command.CommandId" \
        --output text)

      i=1
      while [ $i -le 4 ]; do
        STATUS=$(aws ssm get-command-invocation \
          --command-id "$COMMAND_ID" \
          --instance-id "${self.triggers.instance_id}" \
          --query "Status" \
          --output text || echo "Unknown")

        echo "Attempt $i, status=$STATUS"

        if [ "$STATUS" = "Success" ]; then
          echo "Secret created successfully!"
          exit 0
        fi

        i=$((i + 1))
        sleep 10
      done

      echo "Command timed out!"
      exit 1
    EOT
  }
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