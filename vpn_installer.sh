#!/bin/bash

# VPN One-Click Installer Script
# Supports: Ubuntu, Debian, AlmaLinux, CentOS
# Developed by: Hosteons.com (https://hosteons.com)
# License: MIT

set -e

# Function to detect OS and version
detect_os() {
  if [ -e /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VER=$VERSION_ID
  else
    echo "Unsupported OS"
    exit 1
  fi
}

# Function to prompt for VPN type
choose_vpn_type() {
  echo "Choose VPN type to install:"
  echo "1) WireGuard"
  echo "2) OpenVPN"
  read -rp "Enter your choice [1-2]: " vpn_choice
}

# Install WireGuard
install_wireguard() {
  echo "Installing WireGuard..."
  if [[ $OS_ID == "ubuntu" || $OS_ID == "debian" ]]; then
    apt update && apt install -y wireguard qrencode
  elif [[ $OS_ID == "centos" || $OS_ID == "almalinux" ]]; then
    yum install -y epel-release
    yum install -y wireguard-tools qrencode
  fi

  SERVER_PRIV_KEY=$(wg genkey)
  SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)
  CLIENT_PRIV_KEY=$(wg genkey)
  CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)
  CLIENT_PSK=$(wg genpsk)

  mkdir -p /etc/wireguard
  cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 10.10.0.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIV_KEY

[Peer]
PublicKey = $CLIENT_PUB_KEY
PresharedKey = $CLIENT_PSK
AllowedIPs = 10.10.0.2/32
EOF

  cat <<EOF > /root/client.conf
[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = 10.10.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB_KEY
PresharedKey = $CLIENT_PSK
Endpoint = $(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

  systemctl enable wg-quick@wg0
  systemctl start wg-quick@wg0
  echo "WireGuard setup completed. Client config saved to /root/client.conf"
}

# Install OpenVPN
install_openvpn() {
  echo "Installing OpenVPN..."
  if [[ $OS_ID == "ubuntu" || $OS_ID == "debian" ]]; then
    apt update && apt install -y openvpn easy-rsa
  elif [[ $OS_ID == "centos" || $OS_ID == "almalinux" ]]; then
    yum install -y epel-release
    yum install -y openvpn easy-rsa
  fi

  EASYRSA_DIR=/etc/openvpn/easy-rsa
  mkdir -p "$EASYRSA_DIR"

  if [ ! -f "$EASYRSA_DIR/easyrsa" ]; then
    echo "Copying Easy-RSA files..."
    if [ -d /usr/share/easy-rsa/easyrsa3 ]; then
      cp -r /usr/share/easy-rsa/easyrsa3/* "$EASYRSA_DIR/"
    else
      cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
    fi
  else
    echo "Easy-RSA already initialized at $EASYRSA_DIR"
  fi

  cd "$EASYRSA_DIR" || exit

  EASYRSA=$(find "$EASYRSA_DIR" -type f -name easyrsa | head -n 1)
  chmod +x "$EASYRSA"
  "$EASYRSA" init-pki
  echo | "$EASYRSA" --batch build-ca nopass
  "$EASYRSA" --batch gen-req server nopass
  "$EASYRSA" --batch sign-req server server
  "$EASYRSA" gen-dh
  openvpn --genkey secret ta.key

  [ -f pki/ca.crt ] || { echo "Missing ca.crt"; exit 1; }
  [ -f pki/issued/server.crt ] || { echo "Missing server.crt"; exit 1; }
  [ -f pki/private/server.key ] || { echo "Missing server.key"; exit 1; }
  [ -f pki/dh.pem ] || { echo "Missing dh.pem"; exit 1; }

  cp pki/ca.crt /etc/openvpn/
  cp pki/issued/server.crt /etc/openvpn/
  cp pki/private/server.key /etc/openvpn/
  cp pki/dh.pem /etc/openvpn/
  cp ta.key /etc/openvpn/

  cat <<EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth /etc/openvpn/ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
data-ciphers AES-256-CBC
data-ciphers-fallback AES-256-CBC
cipher AES-256-CBC
auth SHA256
topology subnet
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
dev-node tun0
EOF

  if systemctl list-unit-files | grep -q openvpn@server.service; then
    systemctl enable openvpn@server
    systemctl start openvpn@server
  elif systemctl list-unit-files | grep -q openvpn-server@server.service; then
    systemctl enable openvpn-server@server
    systemctl start openvpn-server@server
  else
    echo "Warning: OpenVPN systemd service not found. Please start manually."
  fi

  CLIENT_OVPN=/root/client.ovpn
  echo "client" > $CLIENT_OVPN
  echo "dev tun" >> $CLIENT_OVPN
  echo "proto udp" >> $CLIENT_OVPN
  echo "remote $(curl -s ifconfig.me) 1194" >> $CLIENT_OVPN
  echo "resolv-retry infinite" >> $CLIENT_OVPN
  echo "nobind" >> $CLIENT_OVPN
  echo "persist-key" >> $CLIENT_OVPN
  echo "persist-tun" >> $CLIENT_OVPN
  echo "remote-cert-tls server" >> $CLIENT_OVPN
  echo "cipher AES-256-CBC" >> $CLIENT_OVPN
  echo "auth SHA256" >> $CLIENT_OVPN
  echo "key-direction 1" >> $CLIENT_OVPN
  echo "verb 3" >> $CLIENT_OVPN

  echo "<ca>" >> $CLIENT_OVPN
  cat pki/ca.crt >> $CLIENT_OVPN
  echo "</ca>" >> $CLIENT_OVPN

  echo "<cert>" >> $CLIENT_OVPN
  cat pki/issued/server.crt >> $CLIENT_OVPN
  echo "</cert>" >> $CLIENT_OVPN

  echo "<key>" >> $CLIENT_OVPN
  cat pki/private/server.key >> $CLIENT_OVPN
  echo "</key>" >> $CLIENT_OVPN

  echo "<tls-auth>" >> $CLIENT_OVPN
  cat ta.key >> $CLIENT_OVPN
  echo "</tls-auth>" >> $CLIENT_OVPN

  echo "OpenVPN setup completed. Client config saved to /root/client.ovpn"
}

# Main logic
detect_os
choose_vpn_type

case $vpn_choice in
  1)
    install_wireguard
    ;;
  2)
    install_openvpn
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac
