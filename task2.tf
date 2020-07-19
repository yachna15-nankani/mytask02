provider "aws" {
 region = "ap-south-1"
}
resource "aws_vpc" "main" {
 cidr_block = "192.168.0.0/16"
 instance_tenancy = "default"
 tags = {
  Name = "myownvpc"
 }
}
resource "aws_subnet" "subnet01" {
 vpc_id = "${aws_vpc.main.id}"
 cidr_block = "192.168.0.0/24"
 availability_zone = "ap-south-1a"
 map_public_ip_on_launch = "true"
 tags = {
  Name = "myownsubnet"
 }
}
resource "aws_internet_gateway" "mygate" { 
 vpc_id = "${aws_vpc.main.id}"
 tags = {
  Name = "myowngate"
 }
}
resource "aws_s3_bucket" "mybucket" {
 bucket = "mybucket"
 acl = "public-read"
 tags = {
  Name = "myownbucket1"
 }
}
resource "aws_s3_bucket_object" "mybucobj13" {
 bucket = aws_s3_bucket.mybuckt.bucket
 key = "images.png"
}
locals {
 s3_origin_id = "aws_s3_bucket.mybuckt.bucket"
 depends_on = [aws_s3_bucket.mybuckt]
}
resource "aws_security_group" "my_security" {
 name = "myownsecurity"
 vpc_id = "${aws_vpc.main.id}"
 ingress {
  description = "SSH"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
  ingress {
  description = "HTTP"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
  ingress {
  description = "NFS"
  from_port = 2049
  to_port = 2049
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
  egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
 }
 tags = {
  Name = "myownsecurity"
 }
}
resource "aws_efs_flie_system" "myefs01" {
 creation_token = "myefs01"
 performance_mode = "generalPurpose"
 tags = {
  Name = "efs-yachna"
 }
}
resource "aws_efs_mount_target" "myefs01-mount" {
 file_system_id = aws_efs_file_system.myefs.id
 subnet_id = aws_subnet.subnet01.id
 vpc_security_group_ids = [aws_security_group.my_security.id]
}
resource "aws_instance" "mywebserver" {
 depends_on = [aws_efs_mount_target.myefs01-mount]
 ami = "ami-0732b62d310b80e97"
 instance_type = "t2.micro"
 key_name = "my1key"
 vpc_security_group_ids = [aws_security_group.my_security.id]
 subnet_id = "${aws_subnet.subnet01.id}" 
 tags = {
  Name = "mywebserver-os"
 }
} 
resource "null_resource" "nullreso1" {
 depends_on = [aws_instance.mywebserver]
 connection {
  type = "ssh"
  user = "ec2-user"
  private_key= file("my1key.pem")
  host = aws_instancemy.webserver.public_ip
}
provisioner "remote-exec" {
 inline = [
  "sudo yum install httpd php git amazon-efs-utils nfs-utils -y",
  "sudo setenforce 0",
  "sudo systemctl start httpd",
  "sudo systemctl enable httpd",
  "sudo mount -t efs ${aws_efs_file_system.myefs01.id}:/ /var/www/html",
  "sudo echo '${aws_efs_file_system.myefs01.id}:/ /var/www/html efs defaults,_netdev 0 0' >> /etc/fstab",
  "sudo rm -rf /var/www/html/*",
  "sudo git clone "
 ]
}
resource "aws_cloudfront_origin_access_identity" "myidentity" {
 comment = "Some Comment"
}
data "aws_iam_policy_document" "mypolicy" {
 statement {
  actions = ["s3:GetObject"]
  resources = ["${aws_s3_bucket.mybucket.arn/*"]
  principals {
   type = "AWS"
   identifiers = ["${aws_cloudfront_origin_access_identity.iam_arn}"]
  }
 }
}
resource "aws_s3_bucket_policy" "myfirst_policy" {
 bucket = aws_s3_bucket.mybucket.id
 policy = data.aws_iam_policy_document.mypolicy.json
}
resource "aws_cloudfront_distribution" "mycloudfront" {
 origin {
    domain_name = "${aws_s3_bucket.mybucket.bucket_regional_domain_name}"
    origin_id   = local.s3_origin_id
    s3_origin_config {
     origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
          }
       }
 enabled = true
 is_ipv6_enabled = true
 wait_for_deployment = false
 default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "PUSH", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
   viewer_protocol_policy = "redirect-to-https"
     min_ttl = 0
     default_ttl = 3600
     max_ttl = 86400
  }
   restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

}
  