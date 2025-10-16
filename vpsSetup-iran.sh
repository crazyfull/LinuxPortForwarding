#!/bin/sh
installPackages() {
	sudo apt update
	sudo apt upgrade -y
	sudo apt install net-tools -y
	sudo apt install socat -y

}
configSSH() {
	sshpath=/etc/ssh/sshd_config
	
	cat <<'EOF' >> $sshpath
#
#ssh port
#Port 61222
#access for root user
PermitRootLogin yes

EOF

sudo service sshd restart

}

installv2ray() {
	bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
 
}

installWebServer() {
git clone https://github.com/crazyfull/RizWEBApp.git
wget http://mojz.ir/moji/settings.ini -O /root/RizWEBApp/settings.ini
wget http://mojz.ir/index.html -O /root/RizWEBApp/www/index.html
sudo /root/RizWEBApp/RizWEB.run -install

}

downloadCert() {
	wget http://mojz.ir/moji/cert.crt -O /01
	wget http://mojz.ir/moji/private.key -O /02

}

C10kproblem() {
##C10k problem
pamdSessionPath=/etc/pam.d/common-session
pamdSessionNonPath=/etc/pam.d/common-session-noninteractive
systemdSystemPath=/etc/systemd/system.conf
systemdUserPath=/etc/systemd/user.conf
limitsPath=/etc/security/limits.conf
sysConfigPath=/etc/sysctl.conf

cat <<'EOF' >> $pamdSessionPath
session required pam_limits.so

EOF

cat <<'EOF' >> $pamdSessionNonPath
session required pam_limits.so

EOF

cat <<'EOF' >> $systemdSystemPath
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535

EOF

cat <<'EOF' >> $systemdUserPath
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535

EOF

cat <<'EOF' >> $sysConfigPath
#enable ip forward
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

#C10k problem
net.core.somaxconn = 65536
net.ipv4.tcp_max_tw_buckets = 1440000
fs.file-max = 2097152

#enable TCPBBR
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

EOF


cat <<'EOF' >> $limitsPath
#
#for C10k add
*   hard    nofile    65535
*   soft    nofile    65535
*   hard    nproc     65535
*   soft    nproc     65535
root soft     nproc          124000
root hard     nproc          124000
root soft     nofile         124000
root hard     nofile         124000

EOF

#
sysctl net.ipv4.tcp_congestion_control
sudo sysctl -p

sudo systemctl daemon-reexec

}


makeMultifinder() {
	path=/root/findMultiuser.sh
	cat <<'EOF' >> $path
#!/bin/sh
netstat -np 2>/dev/null | grep :$1 | awk '{if($3!=0) print $5;}' | cut -d: -f1 | sort | uniq -c | sort -nr | head

EOF
	chmod +x $path

}

#
#installPackages
configSSH
C10kproblem
#installv2ray
#installWebServer
#makeMultifinder
#downloadCert
