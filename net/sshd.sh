#!/bin/bash
# Spawn a sshd on a specified port
# (does not require root privileges)
set -e
script=${0##*/}
socat=$(which socat)

if [ -z $socat ];then
    echo "socat not found, add path manually."
    exit
fi

if [ $# -lt 1 ];then
    echo "Usage: ${script} <port>" >&2
    exit 2
fi

port=$1
# use current users home dir as
# sshd will refuse /tmp because
# of it's permissions.
home=$(echo ~)
tmp_dir=$(mktemp -dt -p $home pki.XXXXXX)
trap "rm -rf $tmp_dir" EXIT TERM

# the example private key (for testing purposes):
#   -----BEGIN EC PRIVATE KEY-----
#   MHcCAQEEIE4zYigR5lDjZcjVrfiaORdT7ob+PaftBcPmcwe7eHq8oAoGCCqGSM49
#   AwEHoUQDQgAED26SXa80cDFnAw1hiAf3W//AIKoxlaa2qPYpl00APYAwE4mBum8g
#   gfou+XEinN5nTOK2aqUgX6affSH/AqLqRw==
#   -----END EC PRIVATE KEY-----
# create your own key with:
#   ssh-keygen -t ecdsa -f id_ecdsa_test
# NOTE: ECDSA is reasonable short (Ed25519 might not be supported)
key="ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHA"
key+="yNTYAAABBBA9ukl2vNHAxZwMNYYgH91v/wCCqMZWmtqj2KZdNAD2AMBOJgbpvI"
key+="IH6LvlxIpzeZ0zitmqlIF+mn30h/wKi6kc= takeshix@WOPR"
echo "$key" > $tmp_dir/authorized_keys

chmod 700 $tmp_dir
chmod 600 $tmp_dir/authorized_keys
ssh-keygen -f $tmp_dir/ssh_host_rsa_key -N '' -t rsa >/dev/null
ssh-keygen -f $tmp_dir/ssh_host_dsa_key -N '' -t dsa >/dev/null
ssh-keygen -f $tmp_dir/ssh_host_ecdsa_key -N '' -t ecdsa >/dev/null
sh -c "cat <<EOF > $tmp_dir/sshd_config
HostKey $tmp_dir/ssh_host_rsa_key
HostKey $tmp_dir/ssh_host_dsa_key
HostKey $tmp_dir/ssh_host_ecdsa_key
AuthorizedKeysFile $tmp_dir/authorized_keys
PermitRootLogin yes
PubkeyAuthentication yes
ChallengeResponseAuthentication yes
UsePAM no
AllowAgentForwarding yes
AllowTcpForwarding yes
PrintMotd no
Subsystem       sftp    /usr/lib/ssh/sftp-server
EOF"

socat tcp-l:$port,fork,reuseaddr exec:"sshd -i -e -f $tmp_dir/sshd_config"
