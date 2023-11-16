#!/bin/bash

ssh_config() {              
    mkdir -p /etc/ssh/
    rm -rf /etc/ssh/ca-key.pub
    echo "${vault_ca_pub_key}" | sed '$d' > /etc/ssh/ca-key.pub
    chmod 644 /etc/ssh/ca-key.pub
    echo "TrustedUserCAKeys /etc/ssh/ca-key.pub" >> /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
}

mysql_config() {
    apt-get update
    apt-get install -y mysql-server

    sudo tee /etc/mysql/mysql.conf.d/mysqld.cnf > /dev/null <<EOT
      [mysqld]
      user                    = mysql
      bind-address            = 0.0.0.0
      mysqlx-bind-address     = 127.0.0.1
      key_buffer_size         = 16M
      myisam-recover-options  = BACKUP
      log_error               = /var/log/mysql/error.log
      max_binlog_size         = 100M
EOT

    echo "CREATE USER '${mysql_user}'@'%' IDENTIFIED WITH caching_sha2_password BY '${mysql_password}';" > /home/ubuntu/demo.sql
    echo "GRANT ALL PRIVILEGES ON *.* TO '${mysql_user}'@'%' WITH GRANT OPTION;" >> /home/ubuntu/demo.sql
    sudo mysql < /home/ubuntu/demo.sql
    systemctl restart mysql
}   

ssh_config
mysql_config