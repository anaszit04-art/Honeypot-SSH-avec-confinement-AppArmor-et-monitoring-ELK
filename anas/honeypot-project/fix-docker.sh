sudo mv /etc/resolv.conf /etc/resolv.conf.bak
sudo tee /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
EOF
