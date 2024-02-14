#!/bin/bash -xe

yum update -y
yum install -y httpd
sudo cp /home/ec2-user/index.html /var/www/html/index.html
sudo systemctl enable httpd
sudo systemctl start httpd