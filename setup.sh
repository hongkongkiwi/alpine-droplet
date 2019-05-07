#!/bin/sh

# Enable openssh server
rc-update add sshd default

# Configure networking
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
auto eth1
iface eth1 inet dhcp
EOF

ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0
ln -s networking /etc/init.d/net.eth1

rc-update add net.lo boot
rc-update add net.eth0 boot
rc-update add net.eth1 boot

# Create root ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Create other directories
mkdir -p /var/lib/cloud/instance
chmod 700 /var/lib/cloud/instance

# Check if Docker installed
if `apk info -vv | grep -q 'docker-[0-9]'`; then
  # Fix the docker issue on v3.8 - https://wiki.alpinelinux.org/wiki/Docker#Alpine_3.8
  echo "cgroup /sys/fs/cgroup cgroup defaults 0 0" >> /etc/fstab
  cat >> /etc/cgconfig.conf <<EOF
mount {
cpuacct = /cgroup/cpuacct;
memory = /cgroup/memory;
devices = /cgroup/devices;
freezer = /cgroup/freezer;
net_cls = /cgroup/net_cls;
blkio = /cgroup/blkio;
cpuset = /cgroup/cpuset;
cpu = /cgroup/cpu;
}
EOF
  rc-update add docker boot
fi

if `apk info -vv | grep -q 'bash-completion-[0-9]'`; then
  # Update BashRC
  cat > /root/.bashrc <<EOF
alias update='apk update && apk upgrade'
export HISTTIMEFORMAT="%d/%m/%y %T "
export TERM=xterm-color
export CLICOLOR=1
export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'
EOF

  cat > /root/.bash_profile <<EOF
# .bash_profile

# If .bash_profile exists, bash doesn't read .profile
if [[ -f ~/.profile ]]; then
  . ~/.profile
fi

# If the shell is interactive and .bashrc exists, get the aliases and functions
if [[ $- == *i* && -f ~/.bashrc ]]; then
    . ~/.bashrc
fi
EOF

  # If bash-completion installed....
  `apk info -vv | grep -q 'bash-completion-[0-9]'` && echo "source /etc/profile.d/bash_completion.sh" >> /root/.bashrc

  # If nano installed....
  `apk info -vv | grep -q 'nano-[0-9]'` && echo "export EDITOR='nano'" >> /root/.bashrc

  # Set bash as default shell
  sed -i 's|root:x:0:0:root:/root:/bin/ash|root:x:0:0:root:/root:/bin/bash|' /etc/passwd
fi

# Grab config from DigitalOcean metadata service
cat > /bin/do-init <<-EOF
#!/bin/sh
resize2fs /dev/vda
wget -T 5 http://169.254.169.254/metadata/v1/hostname    -q -O /etc/hostname
wget -T 5 http://169.254.169.254/metadata/v1/public-keys -q -O /root/.ssh/authorized_keys
wget -T 5 http://169.254.169.254/metadata/v1/vendor-data -q -O /var/lib/cloud/instance/vendor-data.txt
wget -T 5 http://169.254.169.254/metadata/v1/user-data -q -O /var/lib/cloud/instance/user-data.txt
wget -T 5 http://169.254.169.254/metadata/v1/dns/nameservers -q -O - | sed 's|^|nameserver |' > /etc/resolv.conf
chmod 0644 /etc/resolv.conf

setup-timezone -z $(wget -T 5 -q -O - http://169.254.169.254/metadata/v1/region | \
  sed -r 's|AMS[0-9]+|Europe/Amsterdam|I' | \
  sed -r 's|BLR[0-9]+|Asia/Kolkata|I' | \
  sed -r 's|FRA[0-9]+|Europe/Frankfurt|I' | \
  sed -r 's|LON[0-9]+|Europe/London|I' | \
  sed -r 's|NYC[0-9]+|America/New_York|I' | \
  sed -r 's|SFO[0-9]+|America/San_Francisco|I' | \
  sed -r 's|SGP[0-9]+|Asia/Singapore|I' | \
  sed -r 's|TOR[0-9]+|America/Toronto|I')

hostname -F /etc/hostname
chmod 600 /root/.ssh/authorized_keys

# Setup DO-Agent Docker
if `apk info -vv | grep -q 'docker-[0-9]'`; then
  docker run \
    -d \
    -v /proc:/host/proc:ro \
    -v /sys:/host/sys:ro \
    --restart always \
  digitalocean/do-agent:stable
fi

rc-update del do-init default
exit 0
EOF

# Create do-init OpenRC service
cat > /etc/init.d/do-init <<-EOF
#!/sbin/openrc-run
depend() {
    need net.eth0
}
command="/bin/do-init"
command_args=""
pidfile="/tmp/do-init.pid"
EOF

# Make do-init and service executable
chmod +x /etc/init.d/do-init
chmod +x /bin/do-init

# Enable do-init service
rc-update add do-init default

# Check if Docker is installed
if `apk info -vv | grep -q 'docker-[0-9]'`; then
  # Install Docker Compose
  apk add docker-compose --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted
fi
