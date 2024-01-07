#!/bin/bash
echo -e "\nEnter your Destination IP"
read destIP

if ! [[ -n "${destIP}" ]]; then
  echo "error: The destination IP cannot be empty"
  exit 1;
fi

echo -e "\nEnter your Destination IP (between 1-65535):"
read destPort

if [[ $destPort -gt 65535 || $destPort -lt 1 ]]; then
  echo "error: your port value is out of range"
  exit 1;
fi
# get current public ip
currentvIPv4=$(curl https://ipv4.icanhazip.com)

# enable ip-Frowarding
if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
  # if exist value
  current_value=$(grep "^net.ipv4.ip_forward" /etc/sysctl.conf | awk '{print $3}')
  # set new value
  if [ "$current_value" != "1" ]; then
    sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
    echo "net.ipv4.ip_forward changed to ON"
  fi
else
  # add new line
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  echo "Added net.ipv4.ip_forward line to /etc/sysctl.conf file."
fi

# reload new setting
sudo sysctl -p

sudo iptables -A PREROUTING -t nat -p tcp/udp --dport $destPort -j DNAT --to-destination $destIP:$destPort
#disable loopback
sudo iptables -t nat -A POSTROUTING ! -s 127.0.0.1 -j MASQUERADE

echo "\nadded port forwarding [TCP/UDP] from [$currentvIPv4:$destPort] to [$destIP:$destPort]"

