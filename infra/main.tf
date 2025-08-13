resource "aws_instance" "k3s_master" {
  ami                    = var.ami_id
  instance_type          = var.instance_type_master
  key_name               = aws_key_pair.my_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.k3s_master.id]
  subnet_id              = aws_subnet.public_a.id

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
  }

  provisioner "local-exec" {
    command = <<-EOF
      set -e
      TIMEOUT=300
      START_TIME=$(date +%s)
      TOKEN_FILE="k3s_token.txt"

      while true; do
        if (( $(date +%s) - START_TIME > TIMEOUT )); then
          echo "Timeout: K3s token not found after 5 minutes." >&2
          exit 1
        fi

        if ssh -o StrictHostKeyChecking=no -i ${var.key_filename} ec2-user@${self.triggers.master_ip} "sudo test -s /var/lib/rancher/k3s/server/node-token"; then
          ssh -o StrictHostKeyChecking=no -i ${var.key_filename} ec2-user@${self.triggers.master_ip} "sudo cat /var/lib/rancher/k3s/server/node-token" > "$TOKEN_FILE"
          echo "Token successfully saved to $TOKEN_FILE"
          exit 0
        fi

        sleep 5
      done
    EOF
  }
}

resource "null_resource" "kubeconfig_download" {
  depends_on = [null_resource.get_k3s_token, aws_instance.k3s_worker]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "rm -f ./kubeconfig && scp -i ${var.key_filename} -o StrictHostKeyChecking=no ec2-user@${aws_instance.k3s_master.public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig && sed -i 's/127.0.0.1/${aws_instance.k3s_master.public_ip}/g' ./kubeconfig"
  }
}

resource "null_resource" "install_master" {
  depends_on = [null_resource.kubeconfig_download, aws_instance.k3s_worker]

  triggers = {
    master_ip = aws_instance.k3s_master.public_ip
  }

  provisioner "local-exec" {
    command = "export KUBECONFIG=./kubeconfig && kubectl create secret docker-registry ecr-cred --docker-server=${var.aws_account}.dkr.ecr.${var.aws_region}.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password)"
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