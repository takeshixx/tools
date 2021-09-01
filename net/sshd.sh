#!/bin/bash
# Spawn a sshd on a specified port
# (does not require root privileges)
set -o errexit -o pipefail -o noclobber -o nounset -e
script=${0}

function help(){
    echo "Usage: ${script} [port]"
    echo
    echo "-k/--public-key       ssh public key for remote access"
    echo "-r/--restrictions     ssh restrictions for remote access"
    echo "                      valid options: none, nocmd"
    echo "-s/--sshd-bin         provide alternative sshd binary path"
    echo "-v/--verbose          print verbose sshd output (repeat for more output)"
    echo "-h/--help             print this help page"
    exit 1
}

_log(){
    echo "[$(date +'%T')] ${*}"
}

log(){
    _log "[*] ${*}"
}

info(){
    _log "[+] ${*}"
}

err(){
    _log "[E] ${*}"
}

warn(){
    _log "[W] ${*}"
}

sshd_log(){
    while read data; do
        _log "[sshd] ${data}"
    done
}

# Check if the given port is valid
function check_port {
    local -i port="10#${1}"
    if (( $port < 1 || $port > 65535 ));then
        err "Invalid port ${port}"
        exit 1
    fi
}

if [[ $# -lt 1 ]];then
    help
fi


# TODO: options after positional arguments will be ignored
PORT=
PUB_KEY=
NO_RESTRICTIONS=
SSHD_BIN=
VERBOSE=0
POSITIONAL=()
while [[ $# -gt 0 ]];do
    key="$1"
    case $key in
        -k|--public-key)
        PUB_KEY="$2"
        shift
        shift
        ;;
        -r|--restrictions)
        NO_RESTRICTIONS="$2"
        shift
        shift
        ;;
        -s|--sshd-bin)
        SSHD_BIN="$2"
        shift
        shift
        ;;
        -v|--verbose)
        VERBOSE=$((VERBOSE+1))
        shift
        ;;
        -h|--help)
        help
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Validate the given port number
PORT="$1"
if [ -z "$PORT" ];then
    err "No port provided"
    exit 1
fi
check_port "$PORT"

# Check dependencies
socat=$(which socat)
if [ ! -x "$socat" ];then
    err "socat not found or not executable"
    exit
fi

# Check if a public key has been provided
if [ -n "$PUB_KEY" ];then
    PUB_KEY=$(readlink -f "$PUB_KEY")
    if [ ! -f "$PUB_KEY" ];then
        err "Invalid public key file: ${PUB_KEY}"
        exit 1
    else
        if which ssh-keygen >/dev/null;then
            if ! ssh-keygen -l -f "$PUB_KEY" >/dev/null;then
                err "Invalid public key in: ${PUB_KEY}"
                exit 1
            fi
        else
            warn "ssh-keygen not available, skipping public key check"
        fi
    fi
    info "Using public key ${PUB_KEY}"
    PUB_KEY=$(cat "$PUB_KEY")
else
    warn "No public key supplied, using default one"
    # the example private key (for testing purposes):
    #   -----BEGIN EC PRIVATE KEY-----
    #   MHcCAQEEIE4zYigR5lDjZcjVrfiaORdT7ob+PaftBcPmcwe7eHq8oAoGCCqGSM49
    #   AwEHoUQDQgAED26SXa80cDFnAw1hiAf3W//AIKoxlaa2qPYpl00APYAwE4mBum8g
    #   gfou+XEinN5nTOK2aqUgX6affSH/AqLqRw==
    #   -----END EC PRIVATE KEY-----
    # create your own key with:
    #   ssh-keygen -t ecdsa -f id_ecdsa_test
    # NOTE: ECDSA is reasonable short (Ed25519 might not be supported)
    PUB_KEY="ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHA"
    PUB_KEY+="yNTYAAABBBA9ukl2vNHAxZwMNYYgH91v/wCCqMZWmtqj2KZdNAD2AMBOJgbpvI"
    PUB_KEY+="IH6LvlxIpzeZ0zitmqlIF+mn30h/wKi6kc= takeshix@WOPR"
fi

# use current users home dir as
# sshd will refuse /tmp because
# of it's permissions.
home=~
tmp_dir=$(mktemp -dt -p $home pki.XXXXXX)
trap "rm -rf ${tmp_dir}" EXIT TERM

# Apply restrictions to the SSH key. Only reverse port forwarding
# to the local sshd instance should be allowed.
if [ "$NO_RESTRICTIONS" == "none" ];then
    warn "Using no restrictions"
    restrictions=
    echo "${PUB_KEY}" > $tmp_dir/authorized_keys
elif [ "$NO_RESTRICTIONS" == "nocmd" ];then
    info "Restricting shell access"
    restrictions="restrict,command=\"/bin/false\",port-forwarding"
    echo "${restrictions} ${PUB_KEY}" > "$tmp_dir"/authorized_keys
else
    info "Using default restrictions"
    restrictions="restrict,command=\"/bin/false\",port-forwarding"
    restrictions+=",permitopen=\"127.0.0.1:22\""
    echo "${restrictions} ${PUB_KEY}" > "$tmp_dir"/authorized_keys
fi

# Create and configure the sshd execution environment
chmod 700 "$tmp_dir"
chmod 600 "${tmp_dir}/authorized_keys"
ssh-keygen -f "${tmp_dir}/ssh_host_rsa_key" -N '' -t rsa >/dev/null
ssh-keygen -f "${tmp_dir}/ssh_host_dsa_key" -N '' -t dsa >/dev/null
ssh-keygen -f "${tmp_dir}/ssh_host_ecdsa_key" -N '' -t ecdsa >/dev/null

# Create the sshd_config
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

sshd_bin="sshd"
if [ -n "$SSHD_BIN" -a -x "$SSHD_BIN" ];then
    info "Using sshd binary ${SSHD_BIN}"
    sshd_bin="$SSHD_BIN"
fi
sshd_cmd="${sshd_bin} -i -e -f $tmp_dir/sshd_config"
if [ "$VERBOSE" -eq 1 ];then
    sshd_cmd+=" -d"
elif [ "$VERBOSE" -eq 2 ];then
    sshd_cmd+=" -d -d"
fi

socat tcp-l:"$PORT",fork,reuseaddr exec:"$sshd_cmd" |& tee -a sshd_log
