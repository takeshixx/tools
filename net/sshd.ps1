# - if no sshd.exe is installed, download from GitHub: https://github.com/PowerShell/Win32-OpenSSH/releases
# - if firewall is enabled, allow access to port (requires administrative privileges):
#       netsh advfirewall firewall add rule name="allow tcp 2112" dir=in action=allow protocol=TCP localport=2112
# - if executing this script is prohibited, run the following command:
#       powershell -exec bypass
 param (
   [string]$port = "2112",
   [string]$publickey = "",
   [string]$restrictions = "",
   [string]$sshdbin = "",
   [switch]$verbose = $false,
   [switch]$help = $false
 )

 function help(){
    echo "Usage: $($PSCommandPath)"
    echo ""
    echo "-port             listening port (default: $($port))"
    echo "-publickey        ssh public key for remote access"
    echo "-restrictions     ssh restrictions for remote access"
    echo "                  valid options: none, nocmd"
    echo "-sshdbin          provide alternative sshd binary path"
    echo "-verbose          print verbose sshd output (repeat for more output)"
    echo "-help             print this help page"
    exit 1
}

if ($help){
   help
}

$tmp_dir = New-TemporaryFile
rm $tmp_dir
mkdir $tmp_dir

if ($publickey -ne ""){
   $publickey = Resolve-Path $publickey
   if (! [System.IO.File]::Exists($publickey)){
      echo "Public key file $($public_key) is not a valid file"
      exit 1
   }
   ssh-keygen.exe -l -f $publickey
   if ($LastExitCode){
      echo "Invalid public key in $($publickey)"
      exit 1
   }
   $publickey = Get-Content $publickey
} else {
   echo "Using default public key"
   # the example private key (for testing purposes):
   #   -----BEGIN EC PRIVATE KEY-----
   #   MHcCAQEEIE4zYigR5lDjZcjVrfiaORdT7ob+PaftBcPmcwe7eHq8oAoGCCqGSM49
   #   AwEHoUQDQgAED26SXa80cDFnAw1hiAf3W//AIKoxlaa2qPYpl00APYAwE4mBum8g
   #   gfou+XEinN5nTOK2aqUgX6affSH/AqLqRw==
   #   -----END EC PRIVATE KEY-----
   # create your own key with:
   #   ssh-keygen -t ecdsa -f id_ecdsa_test
   # NOTE: ECDSA is reasonable short (Ed25519 might not be supported)
   $key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHA"
   $key += "yNTYAAABBBA9ukl2vNHAxZwMNYYgH91v/wCCqMZWmtqj2KZdNAD2AMBOJgbpvI"
   $key += "IH6LvlxIpzeZ0zitmqlIF+mn30h/wKi6kc= takeshix@WOPR"
}

# apply restrictions
if ($restrictions -eq "none"){
   echo "Using no restrictions"
   echo "$($publickey)" | out-file "$($tmp_dir)/authorized_keys"
} elseif ($restrictions -eq "nocmd"){
   echo "Restricting shell access"
   $restrictions = 'restrict,command="/bin/false",port-forwarding,'
   echo "$($restrictions) $($publickey)" | out-file "$($tmp_dir)/authorized_keys"
} else {
   echo "Using default restrictions"
   $restrictions = 'restrict,command="/bin/false",port-forwarding,'
   $restrictions += 'permitopen="127.0.0.1:22"'
   echo "$($restrictions) $($publickey)" | out-file "$($tmp_dir)/authorized_keys"
}

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

$sshd = ".\sshd.exe"
if ($sshdbin -ne ""){
   $sshdbin = Resolve-Path $sshdbin
   if ([System.IO.File]::Exists($sshdbin)){
      echo "Using sshd.exe from $($sshdbin)"
      $sshd=$sshdbin
   }
} else {
   if (! [System.IO.File]::Exists($sshd)){
      echo ".\sshd.exe not found!"
      exit 1
   }
}
$sshd_cmd = "& $($sshd) -p $port -f $($tmp_dir)/sshd_config"
if ($verbose){
   $sshd_cmd += " -d"
}
Invoke-Expression $sshd_cmd
