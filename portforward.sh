#!/bin/bash

function addPort() {
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
  currentvIPv4=$(curl --silent https://ipv4.icanhazip.com) > /dev/null
  
  # enable ip-Frowarding
  if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    # if exist value
    current_value=$(grep "^net.ipv4.ip_forward" /etc/sysctl.conf | awk '{print $3}')
    # set new value
    if [ "$current_value" != "1" ]; then
      sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
      # reload new setting
      sudo sysctl -p
      echo "net.ipv4.ip_forward changed to ON"
    fi
  else
    # add new line
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    # reload new setting
    sudo sysctl -p
    echo "Added net.ipv4.ip_forward line to /etc/sysctl.conf file."
  fi
  
  sudo iptables -A PREROUTING -t nat -p tcp --dport $destPort -j DNAT --to-destination $destIP:$destPort -m comment --comment "#portForwarding"
  sudo iptables -A PREROUTING -t nat -p udp --dport $destPort -j DNAT --to-destination $destIP:$destPort -m comment --comment "#portForwarding"
  
  #disable loopback
  rule_output=$(sudo iptables -t nat -L POSTROUTING --line-numbers)
  # check before added
  if ! [[ $rule_output == *"! -s 127.0.0.1 -j MASQUERADE"* ]]; then
    sudo iptables -t nat -A POSTROUTING ! -s 127.0.0.1 -j MASQUERADE
  fi

  echo -e "\nadded port forwarding [TCP/UDP] from [$currentvIPv4:$destPort] to [$destIP:$destPort]"
}

function clear() {
  # clear my rules by comment tag
  rulesCount=$(sudo iptables -L -t nat --line-numbers -v | grep "#portForwarding" | wc -l)

  # 
  for i in {1..$rulesCount}; do
    echo "delete rule $rule_number"
    sudo iptables -t nat -D PREROUTING 1
  done
}

function list() {
  # script rules list
  sudo iptables -L -t nat --line-numbers -v | grep "#portForwarding"
}

if [[ "$1" == "clear" ]]; then
  clear
  exit 1;
fi

if [[ "$1" == "list" ]]; then
  list
  exit 1;
fi
addPort
