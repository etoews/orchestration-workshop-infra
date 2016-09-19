#!/bin/bash

ENGINE_VERSION=1.12.1-0~xenial
COMPOSE_VERSION=1.8.0

useradd -d /home/docker -m -s /bin/bash docker
echo docker:training | chpasswd

tee /etc/sudoers.d/docker <<SQRL
docker ALL=(ALL) NOPASSWD:ALL
SQRL

sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service ssh restart

apt-get -q update
apt-get remove -y --purge dnsmasq-base
apt-get -qy install fail2ban git httping apache2-utils htop

apt-get -y install apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list

apt-get -q update
apt-get -y install linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get -y install docker-engine=${ENGINE_VERSION}

sed -i 's,-H fd://$,-H fd:// -H tcp://0.0.0.0:55555,' /lib/systemd/system/docker.service
systemctl daemon-reload
curl --silent localhost:55555 || sudo systemctl restart docker
systemctl start docker || true

wget -q -O /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m`
chmod +x /usr/local/bin/docker-compose

sudo -u docker mkdir -p /home/docker/.ssh
sudo -u docker echo StrictHostKeyChecking no > /home/docker/.ssh/config
cat /root/.ssh/authorized_keys > /home/docker/.ssh/authorized_keys
chown docker:docker /home/docker/.ssh/authorized_keys

docker pull redis
docker pull ruby:alpine
docker pull python:alpine
docker pull node:4-slim
docker pull registry:2
docker pull golang
docker pull busybox

sysctl -w net.netfilter.nf_conntrack_max=1000000

# debug cloud-init
# less /var/log/cloud-init-output.log
