# Configuramos el provider

provider "aws" {
  version = "~> 2.0"
  region = "eu-west-1"
}
####################################

# Creamos el VPC con la red principal
resource "aws_vpc" "tf_book" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "TFBook"
  }
}
####################################

# Creamos la Internet Gateway

resource "aws_internet_gateway" "tf_book" {
  vpc_id = aws_vpc.tf_book.id

  tags = {
    Name = "Internet Gateway of VPC ${aws_vpc.tf_book.tags.Name}"
  }
}
####################################

# Creamos la subred  pública

resource "aws_subnet" "tf_book_a_net_public" {
  vpc_id     = aws_vpc.tf_book.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public zone of ${aws_vpc.tf_book.tags.Name}"
  }
}
####################################

#Creamos los grupos de seguridad para las máquinas que vamos a levantar. Actua a nivel de instancia.
resource "aws_security_group" "allow_tcp_8080" {
  name        = "allow_tcp_8080"
  description = "Allow TCP 8080 port incoming traffic."
  vpc_id      = aws_vpc.tf_book.id

  ingress {
    description = "Allow incoming ICMP"
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outgoing traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tcp_8080"
  }
}
####################################

# Definimos las tablas de ruta publica. OJO la ruta del VCP está implícita y no hace falta indicarla

resource "aws_route_table" "public_routing_table" {
  vpc_id = aws_vpc.tf_book.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf_book.id
  }

  tags = {
    Name = "Routing table for public VPC ${aws_vpc.tf_book.tags.Name} net"
  }
}
####################################

# Asociamos las tablas de rutas creadas a las subredes correspondientes

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.tf_book_a_net_public.id
  route_table_id = aws_route_table.public_routing_table.id
}

####################################

# Subimos la clave pública que tendrá acceso a las máquinas

resource "aws_key_pair" "ssh-vm-igarrido" {
  key_name   = "ssh-vm-igarrido"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEUESj2yvuspny0YBLevVFPdIL3AzuoItqyawnYoaevLY+I4ytXx2SO9Pvv+ufLguLmYYG5UmigfqYE0R/d2VCnoaw+rLae4hty7CuwrfK0TExCu09GtjURY3BOKpm5Us1f8l2fOS3vxrGvsz5Je9luB7xH6G+HbWdxzzBYhcXvn6DqQXHiuKRPy45oD1hyDiEwdYq720hKxRlwvKHxRk4uVByCNk1k4bVQ7eNugOx8Ldrsxwdj5DTMoU6pVSl2XTpd8qVIqkfh0SLNVrE6uUlmHqSds3ubnDpIBLcd9lDZpZ1LHBeKrj1Vd7KqA4r4bDMkPYwi2wyb2ptoorGODu0OfpM9Jx1g1asmxtPDxHiXHik2SQT4JbOZTQ5LzddtpqQx9G22kxmFs2EXmWAboen+1dmiYYOtQ/TdsrtnFV12kLJ/01jSFD2Cykol35iPC5jl32FDFzW6iWuixI2FnsFtNGDr2YoBNqwVu9UwPXCIEepupxkZ7CULYd2/ckNlS3VspsGHVsVlNONPiU/2YnvexFocJygwC9NCwvadj+zkxH7DLYy2FjbGmvGtQo4CEFj4HESbtECvT7nnyoN3iNwxqhDbbn1MFQn74eOfFrm93cCbdkdhB9mDZEDfxrUegIV+iaOymcApjjc74Lfw7uFi7CqnXCXsj45lDqVk7VYNw== ivan@valhalla"
}
####################################

resource "aws_instance" "example" {
  ami                    = "ami-0701e7be9b2a77600"
  instance_type          = "t2.micro"
  availability_zone      = aws_subnet.tf_book_a_net_public.availability_zone
  subnet_id              = aws_subnet.tf_book_a_net_public.id
  security_groups        = [aws_security_group.allow_tcp_8080.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  tags = {
    Name = "terraform-example"
  }
}
