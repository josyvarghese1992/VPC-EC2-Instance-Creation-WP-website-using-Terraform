#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment

sudo service sshd restart

sudo yum install httpd -y
sudo amazon-linux-extras install php7.4
sudo systemctl restart httpd.service
sudo systemctl enable httpd.service

wget https://wordpress.org/wordpress-6.1.zip
unzip wordpress-6.1.zip

sudo cp -a wordpress/* /var/www/html/
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i 's/database_name_here/blog/g' /var/www/html/wp-config.php
sed -i 's/username_here/bloguser/g' /var/www/html/wp-config.php
sed -i 's/password_here/bloguser123/g' /var/www/html/wp-config.php
sed -i 's/localhost/db.sanjos.local/g' /var/www/html/wp-config.php
sudo chown -R apache.apache /var/www/html/*
sudo chown -R apache. /var/www/html/*

sudo systemctl restart httpd.service
