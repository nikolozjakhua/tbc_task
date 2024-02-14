#!/bin/bash -xe

yum update -y
yum install -y httpd
cd /home/ec2-user
chmod 777 healthcheck.sh
sudo cp /home/ec2-user/index.html /var/www/html/index.html
sudo systemctl enable httpd
sudo systemctl start httpd
./healthcheck.sh