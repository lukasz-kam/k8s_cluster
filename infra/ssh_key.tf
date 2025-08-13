resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.my_key.private_key_pem
  filename        = var.key_filename
  file_permission = "0600"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "my_k3s_key"
  public_key = tls_private_key.my_key.public_key_openssh
}