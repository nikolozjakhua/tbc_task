provider "aws" {
  region = var.region
}

#Networking#
resource "aws_vpc" "tbc_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "tbc_task"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "tbc_subnet" {
  vpc_id                  = aws_vpc.tbc_vpc.id
  cidr_block              = var.subnet
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "tbc_task"
  }
}

resource "aws_internet_gateway" "tbc_igw" {
  vpc_id = aws_vpc.tbc_vpc.id
  tags = {
    Name = "tbc_task"
  }
}

resource "aws_route_table" "tbc_rt" {
  vpc_id = aws_vpc.tbc_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tbc_igw.id
  }

  tags = {
    Name = "tbc_task"
  }
}

resource "aws_route_table_association" "tbc_assc" {
  subnet_id      = aws_subnet.tbc_subnet.id
  route_table_id = aws_route_table.tbc_rt.id
}

resource "aws_security_group" "tbc_sg" {
  name        = "tbc_Sg"
  description = "allows access to ec2"
  vpc_id      = aws_vpc.tbc_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.subnet]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# S3 Bucket, File upload, bucket Policy #
resource "aws_s3_bucket" "tbc_s3" {
  bucket = var.s3_name

  tags = {
    Name        = "tbc_bucket"
    Environment = "tbc_task"
  }
}

resource "aws_s3_object" "object" {
  depends_on = [aws_s3_bucket.tbc_s3]
  bucket     = aws_s3_bucket.tbc_s3.id
  key        = "image.png"
  source     = "./image.png"
}

resource "aws_s3_bucket_policy" "allow_access_ec2" {
  bucket = aws_s3_bucket.tbc_s3.id
  policy = data.aws_iam_policy_document.allow_access_to_ec2.json
}

data "aws_iam_policy_document" "allow_access_to_ec2" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.tbc_s3.arn,
      "${aws_s3_bucket.tbc_s3.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket = aws_s3_bucket.tbc_s3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Ec2 Instance profile

resource "aws_iam_role" "tbc_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "tbc_policy" {
  name        = "ec2_policy"
  description = "allow ec2 instance s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "ec2:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tbc-attach" {
  role       = aws_iam_role.tbc_role.name
  policy_arn = aws_iam_policy.tbc_policy.arn
}

resource "aws_iam_instance_profile" "tbc-app" {
  name = "tbc_app"
  role = aws_iam_role.tbc_role.name
}

## EC2 Instances
resource "aws_key_pair" "ssh-key" {
  key_name   = "tbc_key"
  public_key = file(var.public_key_location)
}

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "tbc_ec2_active" {
  ami                         = data.aws_ami.latest-amazon-linux-image.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.tbc_subnet.id
  vpc_security_group_ids      = [aws_security_group.tbc_sg.id]
  key_name                    = aws_key_pair.ssh-key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = "tbc_app"
  user_data                   = base64encode(data.template_file.user_data_active.rendered)

  provisioner "file" {
    content     = data.template_file.index_upload.rendered
    destination = "/home/ec2-user/index.html"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key)
  }

  tags = {
    Name = "tbc_active"
  }
}

resource "aws_instance" "tbc_ec2_standby" {
  ami                         = data.aws_ami.latest-amazon-linux-image.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.tbc_subnet.id
  vpc_security_group_ids      = [aws_security_group.tbc_sg.id]
  key_name                    = aws_key_pair.ssh-key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = "tbc_app"
  user_data                   = base64encode(data.template_file.user_data_standby.rendered)

  provisioner "file" {
    content     = data.template_file.index_upload.rendered
    destination = "/home/ec2-user/index.html"
  }

  provisioner "file" {
    content     = data.template_file.healthcheck.rendered
    destination = "/home/ec2-user/healthcheck.sh"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key)
  }

  tags = {
    Name = "tbc_standby"
  }
}

#Files to upload

data "template_file" "index_upload" {
  template = file("index.html")

  vars = {
    s3_bucket_name = aws_s3_bucket.tbc_s3.bucket
    region         = var.region
    image_key      = aws_s3_object.object.key
  }
}

data "template_file" "healthcheck" {
  template = file("healthcheck.sh")

  vars = {
    ACTIVE_INSTANCE_IP     = aws_instance.tbc_ec2_active.private_ip
    REGION                 = var.region
    ALLOCATION_ID          = aws_eip.vip.allocation_id
  }
}

data "template_file" "user_data_active" {
  template = file("script_active.sh")
}

data "template_file" "user_data_standby" {
  template = file("script_standby.sh")
}

#Elastic IP with association

resource "aws_eip" "vip" {
  domain = "vpc"
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.tbc_ec2_active.id
  allocation_id = aws_eip.vip.id
  
}

# CloudFront

locals {
  s3_origin_id   = "${var.s3_name}-origin"
  s3_domain_name = "${var.s3_name}.s3.${var.region}.amazonaws.com"
}

resource "aws_cloudfront_distribution" "this" {

  enabled = true

  origin {
    origin_id   = local.s3_origin_id
    domain_name = local.s3_domain_name
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  default_cache_behavior {

    target_origin_id = local.s3_origin_id
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 7200
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_100"

}