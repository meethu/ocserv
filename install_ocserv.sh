#!/bin/bash
#######################################################
#                                                     #
# 	 This is a ocserv installation for CentOS 7       #
#       https://github.com/meethu/ocserv              #
#                                                     #
####################################################

#检测是否是root用户
function check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用${Green_background_prefix} sudo su ${Font_color_suffix}来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}

function check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

function install_ocserv(){
	yum install epel-release -y
	yum install wget iptables net-tools ntp ocserv -y

	setenforce 0
	sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
	
	systemctl enable ntpd
	cp -rf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	ntpdate -q cn.pool.ntp.org
	systemctl restart ntpd
	
	systemctl stop firewalld
    systemctl disable firewalld
    
}

function sysconf(){
	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
	echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
	sed -i '/soft nofile/d' /etc/security/limits.conf
	echo "* soft nofile 51200" >> /etc/security/limits.conf
	sed -i '/hard nofile/d' /etc/security/limits.conf
	echo "* hard nofile 51200" >> /etc/security/limits.conf
	sysctl -p >/dev/null 2>&1
}

function set_iptables(){
	chmod +x /etc/rc.d/rc.local
	cat >>  /etc/rc.d/rc.local <<EOF
	service ocserv start
	iptables -F
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A INPUT -p icmp -j ACCEPT
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	iptables -I INPUT -p tcp --dport 80 -j ACCEPT
	iptables -A INPUT -p tcp --dport 443 -j ACCEPT
	iptables -A INPUT -p udp --dport 443 -j ACCEPT
	iptables -A INPUT -j DROP
	iptables -t nat -F
	iptables -t nat -A POSTROUTING -s 10.0.1.0/24 -o eth0 -j MASQUERADE
	#自动调整mtu，ocserv服务器使用
	iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
EOF
	echo "Anyconnect服务器安装完成，服务准备重启，重启后即可正常使用"
	reboot
}

function shell_install() {
	check_root
	check_sys
	if [[ ${release} == "centos" ]]; then
		install_ocserv
		sysconf
		set_iptables
	else
		echo "您的操作系统不是CentOS，请更换操作系统之后再试"  && exit 1
	fi
}
shell_install