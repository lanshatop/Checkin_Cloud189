#!/bin/sh
ip=`ip addr |grep inet |egrep -v "inet6|127.0.0.1" |awk '{print $2}' |awk -F "/" '{print $1}'`
echo "#######################################################################"
echo "                  正在关闭 SElinux 策略及防火墙 请稍等~                "
echo "#######################################################################"
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0
systemctl stop firewalld  && systemctl disable firewalld
cat <<EOF > /etc/yum.repos.d/mariadb.repo
# MariaDB 10.6 CentOS repository list - created 2021-11-23 12:30 UTC
# https://mariadb.org/download/
[mariadb]
name=MariaDB
baseurl=https://mirrors.tuna.tsinghua.edu.cn/mariadb/yum/10.6/centos8-amd64
module_hotfixes=1
gpgkey=https://mirrors.tuna.tsinghua.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
cat <<EOF > /etc/yum.repos.d/zabbix.repo
[zabbix]
name=Zabbix Official Repository - \$basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/zabbix/zabbix/6.0/rhel/8/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591


[zabbix-non-supported]
name=Zabbix Official Repository non-supported - \$basearch
baseurl=https://mirrors.tuna.tsinghua.edu.cn/zabbix/non-supported/rhel/8/\$basearch/
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX
gpgcheck=1
EOF
echo "添加源gpgkey"
curl https://mirrors.tuna.tsinghua.edu.cn/zabbix/RPM-GPG-KEY-ZABBIX-A14FE591 \
-o /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591
curl https://mirrors.tuna.tsinghua.edu.cn/zabbix/RPM-GPG-KEY-ZABBIX \
-o /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX
curl https://mirrors.tuna.tsinghua.edu.cn/zabbix/RPM-GPG-KEY-ZABBIX-A14FE591 \
-o /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX-A14FE591
curl https://mirrors.tuna.tsinghua.edu.cn/zabbix/RPM-GPG-KEY-ZABBIX \
-o /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX
dnf -y install wget vim 
dnf -y install mariadb-server  
dnf install zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent2 -y
echo "#######################################################################"
echo "                正在启动及配置Mariadb数据库 请稍等~                 "
echo "#######################################################################"
systemctl start mariadb && systemctl enable mariadb
while :; do echo
    read -p "设置Mysql数据库root密码（建议使用字母+数字）: " Database_Password 
    [ -n "$Database_Password" ] && break
done

mysqladmin -u root password "$Database_Password"
echo "create database  zabbix default charset utf8 COLLATE utf8_bin;" | mysql -uroot -p$Database_Password
echo "grant all privileges on zabbix.* to zabbix@'localhost' identified by '$Database_Password';" | mysql -uroot -p$Database_Password
echo "flush privileges;" | mysql -uroot -p$Database_Password
echo "#######################################################################"
echo "                 正在导入zabbix数据库架构文件，请稍等~               "
echo "#######################################################################"
zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p$Database_Password zabbix

echo "#######################################################################"
echo "                 正在修改Zabbix配置文件，请稍等~                     "
echo "#######################################################################"
sed -i 's/# DBPassword=/DBPassword='$Database_Password'/' /etc/zabbix/zabbix_server.conf
systemctl restart zabbix-server zabbix-agent2 httpd php-fpm
systemctl enable zabbix-server zabbix-agent2 httpd php-fpm
echo "#######################################################################"
echo "                         开始配置前端                            "
echo "#######################################################################"
while :; do echo
    read -p "设置前端名称: " front_name
    [ -n "$front_name" ] && break
done

cat <<EOF > /etc/zabbix/web/zabbix.conf.php
<?php
// Zabbix GUI configuration file.

\$DB['TYPE']				= 'MYSQL';
\$DB['SERVER']			= 'localhost';
\$DB['PORT']				= '0';
\$DB['DATABASE']			= 'zabbix';
\$DB['USER']				= 'zabbix';
\$DB['PASSWORD']			= '$Database_Password';

// Schema name. Used for PostgreSQL.
\$DB['SCHEMA']			= '';

// Used for TLS connection.
\$DB['ENCRYPTION']		= false;
\$DB['KEY_FILE']			= '';
\$DB['CERT_FILE']		= '';
\$DB['CA_FILE']			= '';
\$DB['VERIFY_HOST']		= false;
\$DB['CIPHER_LIST']		= '';

// Vault configuration. Used if database credentials are stored in Vault secrets manager.
\$DB['VAULT_URL']		= '';
\$DB['VAULT_DB_PATH']	= '';
\$DB['VAULT_TOKEN']		= '';

// Use IEEE754 compatible value range for 64-bit Numeric (float) history values.
// This option is enabled by default for new Zabbix installations.
// For upgraded installations, please read database upgrade notes before enabling this option.
\$DB['DOUBLE_IEEE754']	= true;

\$ZBX_SERVER				= 'localhost';
\$ZBX_SERVER_PORT		= '10051';
\$ZBX_SERVER_NAME		= '$front_name';

\$IMAGE_FORMAT_DEFAULT	= IMAGE_FORMAT_PNG;

// Uncomment this block only if you are using Elasticsearch.
// Elasticsearch url (can be string if same url is used for all types).
//\$HISTORY['url'] = [
//	'uint' => 'http://localhost:9200',
//	'text' => 'http://localhost:9200'
//];
// Value types stored in Elasticsearch.
//\$HISTORY['types'] = ['uint', 'text'];

// Used for SAML authentication.
// Uncomment to override the default paths to SP private key, SP and IdP X.509 certificates, and to set extra settings.
//\$SSO['SP_KEY']			= 'conf/certs/sp.key';
//\$SSO['SP_CERT']			= 'conf/certs/sp.crt';
//\$SSO['IDP_CERT']		= 'conf/certs/idp.crt';
//\$SSO['SETTINGS']		= [];
EOF
echo "#######################################################################"
echo "                 安装已经完成 请移步浏览器           "
echo "                 登录地址为http://$ip/zabbix                         "
echo "                 数据库密码为$Database_Password，尽情享用吧！        "
echo "#######################################################################"