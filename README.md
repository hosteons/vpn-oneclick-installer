# 🔐 VPN One-Click Installer (OpenVPN + WireGuard)

This is a one-click Bash script that installs a secure VPN server using either **OpenVPN** or **WireGuard** on popular Linux distributions.

## ✅ Supported Operating Systems

- Ubuntu 20.04 / 22.04
- Debian 11+
- AlmaLinux 8 / 9
- CentOS 7 / 8

## 🧰 Features

- Choose OpenVPN or WireGuard interactively
- Secure, production-ready defaults
- Easy-RSA automation for OpenVPN (TLS, certs, client config)
- Client `.ovpn` or `.conf` output saved to `/root/`
- Works on Hosteons VPS or any KVM VPS

## 📥 How to Use

```bash
wget https://raw.githubusercontent.com/hosteons/vpn-oneclick-installer/main/vpn_installer.sh
chmod +x vpn_installer.sh
sudo ./vpn_installer.sh
```

## 📂 Output Files

- `/root/client.ovpn` (OpenVPN)
- `/root/client.conf` (WireGuard)

## ⚙️ Example

```bash
Choose VPN type to install:
1) WireGuard
2) OpenVPN
Enter your choice [1-2]:
```

## 🔗 Related Links

- Website: [https://hosteons.com](https://hosteons.com)
- Support: [https://my.hosteons.com](https://my.hosteons.com)
- Blog: [https://blog.hosteons.com](https://blog.hosteons.com)

## 📝 License

This project is licensed under the MIT License. See `LICENSE` file for details.
