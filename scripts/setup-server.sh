#!/usr/bin/env bash
# First-time setup of a fresh Ubuntu 24.04 VPS. Run it once as root:
#   ssh root@<server-ip> 'bash -s' < scripts/setup-server.sh
#
# It creates the "deploy" user (with your SSH key), hardens SSH, enables the firewall,
# fail2ban and automatic security updates, installs Docker and adds swap.
# Keep your root session open and check that `ssh deploy@<server-ip>` works before closing it.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root." >&2
  exit 1
fi
if [ ! -s /root/.ssh/authorized_keys ]; then
  echo "No SSH key in /root/.ssh/authorized_keys: add yours first or you could lock yourself out." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> System updates and base packages"
apt-get update
apt-get -y upgrade
apt-get install -y ca-certificates curl git ufw fail2ban unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> deploy user (same SSH key as root)"
if ! id deploy >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" deploy
fi
usermod -aG sudo deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
install -m 600 -o deploy -g deploy /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys

echo "==> SSH: keys only, no root login"
cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'CONF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
CONF
sshd -t
systemctl reload ssh

echo "==> Firewall: SSH, HTTP and HTTPS only"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

echo "==> fail2ban bans IPs that keep failing SSH logins"
systemctl enable --now fail2ban

echo "==> Docker from Docker's official apt repository"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker deploy

echo "==> 2 GB of swap, so a memory spike doesn't kill Postgres"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi

echo
echo "Done. Next: set a sudo password with 'passwd deploy', then log in as deploy and follow the README."
