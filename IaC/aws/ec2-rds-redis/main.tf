
provider "aws" {
  region = "us-east-1"
}

variable "database-name" { default = "test"}
variable "database-user" { default = "test"}
variable "database-password" {default = "Test1234567890"}
variable "subnet-id" { default = "subnet-0a2e7f4671015de45" }

data "aws_subnet" "private-subnet-1" {
  id = var.subnet-id
}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "dev-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m4.large"
  subnet_id     = data.aws_subnet.private-subnet-1.id
  user_data  = file("setup.sh")
}

resource "aws_ebs_volume" "dev-server-disk" {
  availability_zone = "us-east-1b"
  size              = 40
}

resource "aws_volume_attachment" "dev-server-disk-attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.dev-server-disk.id
  instance_id = aws_instance.dev-server.id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-dev"
  engine               = "redis"
  node_type            = "cache.m4.large"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.6"
  port                 = 6379
}

resource "aws_db_instance" "mysql" {
  identifier           = "mysql-dev"
  allocated_storage    = 50
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.m5.large"
  name                 = var.database-name
  username             = var.database-user
  password             = var.database-password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  apply_immediately    = true
}
