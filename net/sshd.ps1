# - If sshd.exe is not available on the target system, download from GitHub: https://github.com/PowerShell/Win32-OpenSSH/releases
# - If firewall is enabled, allow access to port (requires administrative privileges):
#       netsh advfirewall firewall add rule name="allow tcp 2112" dir=in action=allow protocol=TCP localport=2112
# - If executing this script is prohibited, run the following command before running the script:
#       powershell -exec bypass
 param (
    [string]$port = "2112"
 )
$tmp_dir = New-TemporaryFile
rm $tmp_dir
mkdir $tmp_dir

# the example private key (for testing purposes):
#   -----BEGIN EC PRIVATE KEY-----
#   MHcCAQEEIE4zYigR5lDjZcjVrfiaORdT7ob+PaftBcPmcwe7eHq8oAoGCCqGSM49
#   AwEHoUQDQgAED26SXa80cDFnAw1hiAf3W//AIKoxlaa2qPYpl00APYAwE4mBum8g
#   gfou+XEinN5nTOK2aqUgX6affSH/AqLqRw==
#   -----END EC PRIVATE KEY-----
# create your own key with:
#   ssh-keygen.exe -t ecdsa -f id_ecdsa_test
# NOTE: ECDSA is reasonable short (Ed25519 might not be supported)
$key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHA"
$key += "yNTYAAABBBA9ukl2vNHAxZwMNYYgH91v/wCCqMZWmtqj2KZdNAD2AMBOJgbpvI"
$key += "IH6LvlxIpzeZ0zitmqlIF+mn30h/wKi6kc= takeshix@WOPR"
$restrictions = 'restrict,command="/bin/false",port-forwarding,'
$restrictions += 'permitopen="127.0.0.1:22"'
# apply restrictions
echo "$($restrictions) $($key)" | out-file "$($tmp_dir)/authorized_keys"
#echo "$($key)" | out-file "$($tmp_dir)/authorized_keys"
# fix DOS file for sshd.exe
(get-content "$($tmp_dir)/authorized_keys" -raw).replace("`r`n", "`n") | set-content "$($tmp_dir)/authorized_keys" -force

# set permissions for authorized_keys file
$acl = get-acl "$($tmp_dir)/authorized_keys"
$ard = new-object system.security.accesscontrol.filesystemaccessrule($env:UserName,"Read","Allow")
$acl.SetAccessRule($ard)
$acl.SetAccessRuleProtection($true, $false)
set-acl -path "$($tmp_dir)/authorized_keys" -aclobject $acl

# generate host keys
ssh-keygen.exe -f "$($tmp_dir)/ssh_host_rsa_key" -N '""' -t rsa
ssh-keygen.exe -f "$($tmp_dir)/ssh_host_dsa_key" -N '""' -t dsa
ssh-keygen.exe -f "$($tmp_dir)/ssh_host_ecdsa_key" -N '""' -t ecdsa

# create sshd_config
$sshd_config = @"
HostKey $($tmp_dir)/ssh_host_rsa_key
HostKey $($tmp_dir)/ssh_host_dsa_key
HostKey $($tmp_dir)/ssh_host_ecdsa_key
AuthorizedKeysFile $($tmp_dir)/authorized_keys
PubkeyAuthentication yes
ChallengeResponseAuthentication yes
AllowUsers $env:UserName
AllowAgentForwarding yes
AllowTcpForwarding yes
PrintMotd no
"@
echo $sshd_config | out-file "$($tmp_dir)/sshd_config"
# fix DOS file for sshd.exe
(get-content "$($tmp_dir)/sshd_config" -raw).replace("`r`n", "`n") | set-content "$($tmp_dir)/sshd_config" -force

# open tcp port (only works with administrative privileges)
echo "Trying to open port $($port)"
netsh advfirewall firewall add rule name="allow tcp $($port)" dir=in action=allow protocol=TCP localport=$port

sshd.exe -d -p $port -f "$($tmp_dir)/sshd_config"
