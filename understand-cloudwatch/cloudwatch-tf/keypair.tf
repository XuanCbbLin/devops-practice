# 產生一組新的 RSA 金鑰
resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 把公鑰上傳到 AWS，建立 Key Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-generated-key"
  public_key = tls_private_key.my_key.public_key_openssh
}

# 把私鑰輸出到檔案
resource "local_file" "private_key_pem" {
  filename        = "${path.module}/terraform-generated-key.pem"
  content         = tls_private_key.my_key.private_key_pem
  file_permission = "0600"
}
