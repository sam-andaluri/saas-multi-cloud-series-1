
provider "aws" {
  region = "us-east-1"
}

variable "database-name" { default = "test"}
variable "database-user" { default = "test"}
variable "database-password" {default = "Test1234567890"}
variable "subnet-id-1" { default = "subnet-000c9e5aaa3765b4a" }
variable "subnet-id-2" { default = "subnet-038f2c05c4e929e5d" }


variable "security_groups" {default =["sg-04ba7286a62904bcd"] }

variable "instance_name" {default = "devServer"}

data "aws_subnet" "private-subnet-1" {
  id = var.subnet-id-1
}
data "aws_subnet" "private-subnet-2" {
  id = var.subnet-id-2
}
resource "aws_instance" "dev-server" {
  ami           = "ami-019212a8baeffb0fa"
  instance_type = "m4.xlarge"
  key_name =      "doit1"
  user_data  =    file("setup.sh")
  vpc_security_group_ids = var.security_groups
 
  subnet_id     = data.aws_subnet.private-subnet-1.id

  
  tags = {
    Name = var.instance_name
  }

}

resource "aws_ebs_volume" "dev-server-disk" {
  availability_zone = "us-east-1a"
  size              = 100

  tags = {
    Name = var.instance_name
  } 
}

resource "aws_volume_attachment" "dev-server-disk-attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.dev-server-disk.id
  instance_id = aws_instance.dev-server.id
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {

  name = "redis-subnet"
  subnet_ids = [var.subnet-id-1]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-dev"
  engine               = "redis"
  node_type            = "cache.r4.large"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.6"  
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = var.security_groups
}
resource "aws_db_subnet_group" "mysql" {
  name       = "mysql"
  subnet_ids = [var.subnet-id-1, var.subnet-id-2]
}

resource "aws_db_instance" "mysql" {
  identifier           = "mysql-dev"
  allocated_storage    = 50
  engine               = "mysql"
  engine_version       = "8.0.25"       
  instance_class       = "db.m6g.large"
  name                 = var.database-name
  username             = var.database-user
  password             = var.database-password
  parameter_group_name = "default.mysql8.0"  
  skip_final_snapshot  = true
  apply_immediately    = true 
  db_subnet_group_name = aws_db_subnet_group.mysql.name
  vpc_security_group_ids= var.security_groups
}

