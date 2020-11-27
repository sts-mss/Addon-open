#!/bin/bash

# 30/06/20 Author: John Barnett
# Nov/27/2020 Last Edited by: Moath Maharmeh
# Project home = https://gitlab.com/J-C-B/community-splunk-scripts

# Handy commands for troubleshooting
## tcpdump -i eth0 'port 514'                                                               ## see the flow over a port as events are received (or not)
## /usr/sbin/syslog-ng -F -p /var/run/syslogd.pid                                           ## run syslog-ng and see more errors
## 0 5 * * * /bin/find /opt/log/splunk-syslog/ -type f -name \*.log -mtime +1 -exec rm {} \;   ## add this crontab to delete files off every day at 5am older than 1 day
## multitail -s 2 /opt/log/splunk-syslog/*/*/*.log  /opt/splunk/var/log/splunk/splunkd.log     ## monitor all the files in the splunk dir
## syslog-ng-ctl stats                                                                      ## See the stats for each filter

echo "LANG=en_US.utf-8
LC_ALL=en_US.utf-8
" > /etc/environment

#Update package lists
yum update -y


# Install tools
yum install nano wget tcpdump firewalld net-tools netstat multitail htop lsof git iptraf-ng unzip syslog-ng -y
systemctl start firewalld


# remove default sysloger
yum remove rsyslog -y


# Add epel repo for installing syslog-ng
cd $tmp_dir_path
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh epel-release-latest-7.noarch.rpm
#wget -O czanik-syslog-ng314-epel-7.repo https://copr.fedorainfracloud.org/coprs/czanik/syslog-ng314/repo/epel-7/czanik-syslog-ng314-epel-7.repo
#mv czanik-syslog-ng314-epel-7.repo /etc/yum.repos.d/


wget -O czanik-syslog-ng329-epel-7.repo https://copr.fedorainfracloud.org/coprs/czanik/syslog-ng329/repo/epel-7/czanik-syslog-ng329-epel-7.repo
mv czanik-syslog-ng329-epel-7.repo /etc/yum.repos.d/



tmp_dir_path=$(mktemp -d -t splunk-XXXXXXXXXX)
echo "[+] Using temp directory: $tmp_dir_path"


# Create users
adduser syslog-ng
adduser splunk

# Add users to group required
groupadd splunk
usermod -aG splunk syslog-ng
usermod -aG splunk splunk

mkdir -p /opt/log/splunk-syslog


#Show original state
firewall-cmd --list-all
#Splunk ports
firewall-cmd --zone=public --add-port=8000/tcp --permanent # Web UI Port
firewall-cmd --zone=public --add-port=8080/tcp --permanent # HEC port
firewall-cmd --zone=public --add-port=8088/tcp --permanent # HEC port
firewall-cmd --zone=public --add-port=8089/tcp --permanent # Managment Port
firewall-cmd --zone=public --add-port=9997/tcp --permanent # Data flow
#Syslog listeners
firewall-cmd --zone=public --add-port=514/tcp --permanent
#firewall-cmd --zone=public --add-port=1514/tcp --permanent
#firewall-cmd --zone=public --add-port=1515/tcp --permanent
#firewall-cmd --zone=public --add-port=1516/tcp --permanent
#firewall-cmd --zone=public --add-port=1517/tcp --permanent
#firewall-cmd --zone=public --add-port=1518/tcp --permanent
#firewall-cmd --zone=public --add-port=1514/udp --permanent
firewall-cmd --zone=public --add-port=514/udp --permanent
#reload the setting to take effect
firewall-cmd --reload
#Check applied
firewall-cmd --list-all


# Splunk Resources Limits
cd $tmp_dir_path
wget -O 99-splunk.conf 'https://vegalayer.com.com/splunk/configs/99-splunk.conf'

echo "[+] 99-splunk.conf -> /etc/security/limits.d/"
mv 99-splunk.conf /etc/security/limits.d/
cd $tmp_dir_path


# Deal with THP
# https://docs.splunk.com/Documentation/Splunk/7.2.5/ReleaseNotes/SplunkandTHP

# Check THP status
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag


# Disable THP at boot
cd $tmp_dir_path
wget -O disable-thp.service 'https://vegalayer.com.com/splunk/configs/disable-thp.service'
echo "[+] disable-thp.service -> /etc/systemd/system/"
mv disable-thp.service /etc/systemd/system/

sudo systemctl daemon-reload

# Start the disable-thp daemon
systemctl start disable-thp

# Disable THP at startup
systemctl enable disable-thp


# THP now disabled
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag


# Set file limits
mkdir -p /etc/systemd/user.conf.d/

echo "
## Created with JB Splunk Install script by magic
## https://docs.splunk.com/Documentation/Splunk/8.0.3/Installation/Systemrequirements#Considerations_regarding_system-wide_resource_limits_on_.2Anix_systems
[Manager]
DefaultLimitFSIZE=-1
DefaultLimitNOFILE=64000
DefaultLimitNPROC=16000
#LimitFSIZE=infinity   # A setting of infinity sets the file size to unlimited.
#LimitDATA=17179869184  #16GB - The maximum RAM you want Splunk Enterprise to allocate in bytes
#TasksMax=16000        #The maximum number of tasks that a service can create. This setting aligns with the user process limit LimitNPROC and the value can be set to match. For example, 16000
" > /etc/systemd/user.conf.d/splunk.conf


# Disable SELINUX
setenforce 0
sed "s/SELINUX=enforcing/SELINUX=disabled/g" -i /etc/sysconfig/selinux
sed "s/SELINUXTYPE=targeted/#SELINUXTYPE=targeted/g" -i /etc/sysconfig/selinux

sed "s/SELINUX=enforcing/SELINUX=disabled/g" -i /etc/selinux/config
sed "s/SELINUXTYPE=targeted/#SELINUXTYPE=targeted/g" -i /etc/selinux/config

#sed -i'' -e "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux


# Add syslog listener
# cd $tmp_dir_path
# mkdir -p /etc/syslog-ng/conf.d/
# wget -O listeners_4_splunk.conf 'https://vegalayer.com.com/splunk/configs/syslog-ng/listeners_4_splunk.conf'
# echo "[+] Adding Syslog-ng splunk listener listeners_4_splunk.conf"
# echo "[+] listeners_4_splunk.conf -> /etc/syslog-ng/conf.d/"
# mv listeners_4_splunk.conf /etc/syslog-ng/conf.d/
# cd $tmp_dir_path


#enable syslog-ng
systemctl enable syslog-ng
systemctl start syslog-ng

chown -R splunk:splunk /opt/log


# add Splunk
cd /opt
mkdir -p /opt/splunk/etc

echo "[+] Downloading splunk-8.1.0-f57c09e87251-Linux-x86_64.tgz"

#wget -O splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.5.1&product=splunk&filename=splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz&wget=true'
#wget -O splunk-7.3.0-657388c7a488-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.3.0&product=splunk&filename=splunk-7.3.0-657388c7a488-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.0.3&product=splunk&filename=splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.0.6&product=splunk&filename=splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz&wget=true'
wget -O splunk-8.1.0-f57c09e87251-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.1.0&product=splunk&filename=splunk-8.1.0-f57c09e87251-Linux-x86_64.tgz&wget=true'


#tar -xf splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz
#tar -xf splunk-7.3.0-657388c7a488-Linux-x86_64.tgz
# tar -xf splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz
#tar -xf splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz
tar -xf splunk-8.1.0-f57c09e87251-Linux-x86_64.tgz


chown -R splunk:splunk splunk

# Skip Splunk Tour and Change Password dialogue
touch -p /opt/splunk/etc/.ui_login

########################## Install apps
cd $tmp_dir_path
mkdir spk_apps
cd spk_apps

echo "Installing Splunk Base Apps..."

# 9997 listener app
wget --no-check-certificate 'https://vegalayer.comm/splunk/live/apps/tcp_listener.tar.gz'

# syslog-ng configs app
wget --no-check-certificate 'https://vegalayer.comm/splunk/live/apps/syslogng_monitors.tar.gz'

# Universal forwarder app. HF server -> Indexer server
# Add listener for splunk TCP 9997 (for UF and other HWF)
# Replace indexer server ip in /opt/splunk/etc/apps/uf_outputs/local/outputs.conf
wget --no-check-certificate 'https://vegalayer.comm/splunk/live/apps/uf_outputs.tar.gz'

for f in *.tar.gz; do tar -zxf "$f" -C /opt/splunk/etc/apps/; done


########################## Installing addons
cd $tmp_dir_path
mkdir spk_addons
cd spk_addons

wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/splunk-health-assistant-add-on_11.tgz'
wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/Splunk_TA_microsoft_ad.tar.gz'
wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/Splunk_TA_microsoft_dns.tar.gz'
wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/Splunk_TA_microsoft-iis.tar.gz'
wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/Splunk_TA_windows_indexer.tar.gz'
wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/TA-microsoft-sysmon_indexer.tar.gz'
wget --no-check-certificate 'https://vegalayer.com/splunk/live/addons/python-for-scientific-computing-for-linux-64-bit_202.tgz'


for f in *.tar.gz; do tar -zxf "$f" -C /opt/splunk/etc/apps/; done
#for f in *.tar; do tar -xvf "$f" -C /opt/splunk/etc/apps/; done
for f in *.tgz; do tar -xf "$f" -C /opt/splunk/etc/apps/; done
cd $tmp_dir_path


# Enable SSL Login for Splunk
echo "Enable WebUI TLS"
 
echo "
[settings]
httpport = 8000
enableSplunkWebSSL = true
# login_content = Welcome to your Splunk HWF!
" > /opt/splunk/etc/system/local/web.conf

mkdir -p /etc/init.d/splunk

chown -R splunk:splunk /opt/

echo "Starting Splunk - fire it up!! and enabling Splunk to start at boot time with user=splunk "

/opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --seed-passwd Massive_SV8VdRiYiman --answer-yes --auto-ports --no-prompt
/opt/splunk/bin/splunk start


echo "Cleaning up..."
rm -rf /opt/splunk-8.1.0-f57c09e87251-Linux-x86_64.tgz
rm -rf /opt/splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz
rm -rf /opt/splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz
rm -rf /opt/splunk-7.3.0-657388c7a488-Linux-x86_64.tgz
rm -rf /opt/splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz


# Adjust permissions
chown -R splunk:splunk /opt/


echo "
#################################################################
########## Installation complete
#################################################################
########## for splunk https://<server-ip>:8000
########## user = admin password=Massive_SV8VdRiYiman
#################################################################"

#curl -k https://localhost:8000

# Test - command below should trigger syslog-ng to log an event for Splunk to collect
#logger -n 127.0.0.1 -P 514 " **** cisco test event **** Apr 07 01:59:19: %ASA-4-338002: Dynamic Filter monitored blacklisted TCP traffic from CyberRange-Dev-Red:224.10.25.172/56290 (224.10.25.172/56290) to Backbone:224.10.25.1/80 (224.10.25.1/80), destination 224.10.1.172 resolved from dynamic list: 224.10.1.172, threat-level: very-high, category: Malware"
#logger -n 127.0.0.1 -P 514 " **** catchall test event **** Apr 07 01:59:19: **** catchall: **** test event **** "
#logger -n 127.0.0.1 -P 514 " **** juniper test event **** 1 2019-04-08T20:17:19.120+12:00 Internet RT_FLOW - RT_FLOW_SESSION_CREATE [junos@2636.1.1.1.2.40 source-address="10.176.101.11" source-port="59627" destination-address="192.168.10.25" destination-port="8400" service-name="None" nat-source-address="10.176.11.11" nat-source-port="59627" nat-destination-address="192.168.10.25" nat-destination-port="8400" src-nat-rule-name="None" dst-nat-rule-name="None" protocol-id="6" policy-name="248" source-zone-name="Trust" destination-zone-name="DMZ_2" session-id-32="138471" username="N/A" roles="N/A" packet-incoming-interface="reth0.0"] session created 10.176.101.11/59627->192.168.10.25/8400 None 10.176.101.11/59627->192.168.10.25/8400 None None 6 248 Trust DMZ_2_A2 138471 N/A(N/A) reth0.0"
#logger -n 127.0.0.1 -P 514 " **** fortinet test event **** date=2019-04-08,time=20:33:26,devname=3kUnitB,devid=FG3K2C31,logid=0315012544,type=utm,subtype=webfilter,eventtype=urlfilter,level=warning,vd="CCorp",urlfilteridx=3,urlfilterlist="Microsoft-Wildcard",policyid=4303,sessionid=3097985850,user="",srcip=10.250.35.24,srcport=54653,srcintf="V1215-EPZP",dstip=54.214.227.245,dstport=443,dstintf="root",proto=6,service=HTTPS,hostname="aztec.brightmail.com",profile="Microsoft-Wildcard",action=blocked,reqtype=direct,url="/",sentbyte=346,rcvdbyte=3523,direction=outgoing,msg="URL was blocked because it is in the URL filter list",crscore=30,crlevel=high"



## If you are creating a golden image, run this command before locking to prevent duplicate guids etc
# /opt/splunk/bin/splunk clone-prep-clear-config
