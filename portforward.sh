#!/bin/bash

TAG="portForwarding"

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi

install_persistent() {

  if command -v netfilter-persistent >/dev/null 2>&1 || \
     systemctl list-unit-files | grep -q iptables.service; then
    return
  fi

  if [ -f /etc/debian_version ]; then
    apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
  elif [ -f /etc/redhat-release ]; then
    yum install -y iptables-services
    systemctl enable iptables
    systemctl start iptables
  fi
}

IFACE=$(ip route | awk '/^default/ {print $5; exit}')
if [ -z "$IFACE" ]; then
  echo "Cannot detect internet interface"
  exit 1
fi

PUBLIC_IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)

enable_forwarding() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sed -i '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
}

save_rules() {
  if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
  elif systemctl list-unit-files | grep -q iptables.service; then
    service iptables save
  fi
}

addPort() {

  install_persistent
  enable_forwarding

  echo "Select protocol:"
  echo "1) TCP"
  echo "2) UDP"
  read -p "Enter choice (1 or 2): " protoChoice

  case "$protoChoice" in
    1) PROTO="tcp" ;;
    2) PROTO="udp" ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac

  read -p "Enter Source Port (1-65535): " sourcePort
  if ! [[ "$sourcePort" =~ ^[0-9]+$ ]] || [ "$sourcePort" -lt 1 ] || [ "$sourcePort" -gt 65535 ]; then
    echo "Invalid source port"
    exit 1
  fi

  read -p "Enter Destination IP: " destIP
  if ! [[ "$destIP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Invalid destination IP"
    exit 1
  fi

  read -p "Enter Destination Port (1-65535): " destPort
  if ! [[ "$destPort" =~ ^[0-9]+$ ]] || [ "$destPort" -lt 1 ] || [ "$destPort" -gt 65535 ]; then
    echo "Invalid destination port"
    exit 1
  fi

  # DNAT
  iptables -t nat -C PREROUTING -p $PROTO --dport $sourcePort \
  -j DNAT --to-destination $destIP:$destPort \
  -m comment --comment "$TAG" 2>/dev/null || \
  iptables -t nat -A PREROUTING -p $PROTO --dport $sourcePort \
  -j DNAT --to-destination $destIP:$destPort \
  -m comment --comment "$TAG"

  # FORWARD accept
  iptables -C FORWARD -p $PROTO -d $destIP --dport $destPort \
  -m state --state NEW,ESTABLISHED,RELATED 2>/dev/null || \
  iptables -A FORWARD -p $PROTO -d $destIP --dport $destPort \
  -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  iptables -C FORWARD -p $PROTO -s $destIP --sport $destPort \
  -m state --state ESTABLISHED,RELATED 2>/dev/null || \
  iptables -A FORWARD -p $PROTO -s $destIP --sport $destPort \
  -m state --state ESTABLISHED,RELATED -j ACCEPT

  # MASQUERADE
  iptables -t nat -C POSTROUTING -o $IFACE -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE

  save_rules

  echo "Forwarded $PROTO $PUBLIC_IP:$sourcePort → $destIP:$destPort"
}

clearRules() {
  while iptables -t nat -S PREROUTING | grep -q "$TAG"; do
    RULE=$(iptables -t nat -S PREROUTING | grep "$TAG" | head -n1)
    iptables -t nat ${RULE/-A/-D}
  done
  save_rules
  echo "All forwarding rules removed"
}

listRules() {
  iptables -t nat -L PREROUTING -n -v --line-numbers | grep "$TAG"
}

case "$1" in
  clear)
    clearRules
    ;;
  list)
    listRules
    ;;
  help)
    echo "Usage:"
    echo "$0        → add new forward"
    echo "$0 list   → list rules"
    echo "$0 clear  → remove rules"
    ;;
  *)
    addPort
    ;;
esac

exit 0
