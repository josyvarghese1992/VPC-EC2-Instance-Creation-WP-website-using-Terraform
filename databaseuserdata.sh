#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment

sudo  systemctl restart sshd.service

sudo yum install -y mariadb-server
sudo systemctl restart mariadb.service
sudo systemctl enable mariadb.service

sudo mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('mysqlroot123') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
EOF

sudo mysql -u root -pmysqlroot123  -e "create database blog;"

sudo mysql -u root -pmysqlroot123 -e "create user 'bloguser'@'%' identified by 'bloguser123';"

sudo mysql -u root -pmysqlroot123  -e "grant all privileges on blog.* to 'bloguser'@'%';"

sudo mysql -u root -pmysqlroot123 -e "flush privileges;"
