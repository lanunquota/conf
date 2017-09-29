# install 
yum -y install squid nano epel-release dropbear
chkconfig squid on

# disable ping flood
sed -i '$ a net.ipv4.icmp_echo_ignore_all = 1' /etc/sysctl.conf
sysctl -p

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
service sshd restart

#disable_selinux
echo -e "[\033[33m*\033[0m] Disabling SELinux"
sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config >> $LOG 2>&1
setenforce 0 >> $LOG 2>&1

# setting port ssh
sed -i '/Port 22/a Port 80' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port  22/g' /etc/ssh/sshd_config
service sshd restart
chkconfig sshd on

# install dropbear
yum -y install dropbear
echo "OPTIONS=\"-p 443\"" > /etc/sysconfig/dropbear
echo "/bin/false" >> /etc/shells
service dropbear restart
chkconfig dropbear on

#install_nginx
echo -e "[\033[33m*\033[0m] Installing & Configuring NGINX Webserver"
yum install nginx --enablerepo=epel -y >> $LOG 2>&1

#  awk 'NR== 21 { print "map $scheme $https {" ; print "default off;" ; print "https on;"; print "}"} { print }' /etc/nginx/nginx.conf > /tmp/nginx.conf
#  rm -f /etc/nginx/nginx.conf
#  mv /tmp/nginx.conf /etc/nginx

systemctl disable httpd >> $LOG 2>&1
systemctl enable nginx >> $LOG 2>&1
systemctl start nginx >> $LOG 2>&1
  
yum install php php-fpm php-cli php-mysql php-gd php-imap php-ldap php-odbc php-pear php-xml php-xmlrpc php-pecl-apc php-magickwand php-magpierss php-mbstring php-mcrypt php-mssql php-shout php-snmp php-soap php-tidy -y >> $LOG 2>&1
sed -i -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php.ini >> $LOG 2>&1
systemctl enable php-fpm >> $LOG 2>&1
systemctl start php-fpm >> $LOG 2>&1
yum install -y fcgi-devel >> $LOG 2>&1

echo -e "  [\033[33m*\033[0m] Compil fcgiwrap (cause it don't exist in rpm for CentOS)"
cd /usr/local/src/
git clone git://github.com/gnosek/fcgiwrap.git >> $LOG 2>&1
echo -e "  [\033[32m*\033[0m] Gitting sources done"
cd fcgiwrap
autoreconf -i >> $LOG 2>&1 
./configure >> $LOG 2>&1
make >> $LOG 2>&1
make install >> $LOG 2>&1
echo -e "  [\033[32m*\033[0m] fcgiwrap done"

yum install spawn-fcgi -y >> $LOG 2>&1
echo -e "[\033[33m*\033[0m] Setting /etc/sysconfig/spawn-fcgi configuration file"
cat <<EOF > /etc/sysconfig/spawn-fcgi
# You must set some working options before the "spawn-fcgi" service will work.
#
# If SOCKET points to a file, then this file is cleaned up by the init script. #
# See spawn-fcgi(1) for all possible options.
# 
# Example :
#SOCKET=/var/run/php-fcgi.sock
#OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"

FCGI_SOCKET=/var/run/fcgiwrap.socket
FCGI_PROGRAM=/usr/local/sbin/fcgiwrap
FCGI_USER=apache
FCGI_GROUP=apache
FCGI_EXTRA_OPTIONS="-M 0770"
OPTIONS="-u $FCGI_USER -g $FCGI_GROUP -s $FCGI_SOCKET -S $FCGI_EXTRA_OPTIONS -F 1 -P /var/run/spawn-fcgi.pid -- $FCGI_PROGRAM"
EOF

usermod -a -G apache nginx >> $LOG 2>&1
systemctl enable spawn-fcgi >> $LOG 2>&1
systemctl start spawn-fcgi >> $LOG 2>&1
  
# install squid
yum -y install squid
wget -O /etc/squid/squid.conf "https://raw.githubusercontent.com/lanunquota/conf/master/squid-centos.conf"
MYIP=`curl -s ifconfig.me`;
MYIP2="s/xxxxxxxxx/$MYIP/g";
sed -i $MYIP2 /etc/squid/squid.conf;
chkconfig squid on
service squid restart

# install fail2ban
yum -y install fail2ban
service fail2ban restart
chkconfig fail2ban on

# remove unused
yum -y remove sendmail;
yum -y remove httpd;
yum -y remove cyrus-sasl

# downlaod script
cd /usr/bin
curl https://raw.githubusercontent.com/lanunquota/conf/master/tQBgFJ5b > user-login.sh
curl https://raw.githubusercontent.com/lanunquota/conf/master/Bu3f4DPW > user-expired.sh
curl https://raw.githubusercontent.com/lanunquota/conf/master/X6p2b9nZ > user-add.sh
curl https://raw.githubusercontent.com/lanunquota/conf/master/rYEdJMeB > user-trial.sh
curl https://raw.githubusercontent.com/lanunquota/conf/master/np5dXPD2 > user-limit.sh
sed -i $MYIP2 /usr/bin/user-trial.sh;
echo "* * * * * root /usr/bin/user-limit.sh" > /etc/crontab
echo "* * * * * root sleep 5; /usr/bin/user-limit.sh" > /etc/crontab
echo "* * * * * root sleep 10; /usr/bin/user-limit.sh" > /etc/crontab
echo "* * * * * root sleep 15; /usr/bin/user-limit.sh" > /etc/crontab
chmod +x /usr/bin/user-login.sh
chmod +x /usr/bin/user-expired.sh
chmod +x /usr/bin/user-add.sh
chmod +x /usr/bin/user-trial.sh
chmod +x /usr/bin/user-limit.sh

# finalisasi
service sshd restart
service squid restart
service dropbear restart
service fail2ban restart
service crond restart
chkconfig crond on

# info
clear
echo "Auto Installer by PerantauSepi (izam-lukman)" | tee log-install.txt
echo "===============================================" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Service"  | tee -a log-install.txt
echo "-------"  | tee -a log-install.txt
echo "Fail2Ban : [on]"  | tee -a log-install.txt
echo "OpenSSH  : 80"  | tee -a log-install.txt
echo "DropBear : 443"  | tee -a log-install.txt
echo "Squid3   : 8080 (limit to IP SSH)"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "Script"  | tee -a log-install.txt
echo "------"  | tee -a log-install.txt
echo "./user-login.sh"  | tee -a log-install.txt
echo "./user-expired.sh"  | tee -a log-install.txt
echo "./user-add.sh"  | tee -a log-install.txt
echo "./user-trial.sh"  | tee -a log-install.txt
echo "./user-limit.sh"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "SILA REBOOT VPS ANDA ! shutdown -r now"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "==============================================="  | tee -a log-install.txt
