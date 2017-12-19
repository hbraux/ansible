#!/bin/bash

# Constants (host)
VAGRANT_PROVIDER=virtualbox
DEFAULT_MEMORY=1024
DEFAULT_CPU=1

# variables
declare ServerType
declare ServerList
declare -i ServerCount=0
declare Playbook
declare HostIp
declare HostFile
declare Domain
declare VagrantStatus
declare VagrantId
declare -i VagrantChanged=0

function die {
  echo "DEPLOY [ *** ERROR *** $1 ]"
  exit 1
}
function info {
  echo
  echo "DEPLOY [ $1 ]"
}

function usage {
  echo "Usage: $0 [-<options>] <pattern> | <command> <pattern> 

Supported options:
  -v[vv] : verbosity

Supported commands:
 deploy   : deploy server(s). this is the default command
 shutdown : shutdown server(s)
 destroy  : destroy server(s)
 status   : servers satus
"; exit
}

function getDomain {
  Domain=$(uname -n)
  Domain=${Domain#*.}
}

function getHostIp {
  HostIp=$(netstat -rn  | grep eth0 | grep '255.255.255' | cut -d\  -f1 | sed 's/.0$/.1/')
  nc -w 1 $HostIp 22 </dev/null >/dev/null || die "port 22 not opened on $VAGRANT_PROVIDER host $HostIp -> start freeSSHd!"
}



function checkSshConf {
  [ -f $HOME/.ssh/id_rsa.pub ] || die "No SSH key found on localhost"
  [ -f $HOME/.ssh/config ] || touch $HOME/.ssh/config
  if [ $(grep -c "\*\.$domain" $HOME/.ssh/config) -eq 0 ]
  then info "Updating $HOME/.ssh/config"
       echo "
Host *.$Domain
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
" >>$HOME/.ssh/config
  fi
} 

function checkCacheDir {
  if [[ -n $DEPLOY_CACHE_DIR ]]
  then [[ -d $DEPLOY_CACHE_DIR ]] || die "Directory $DEPLOY_CACHE_DIR does not exist"
  else # default dir
    export DEPLOY_CACHE_DIR=$HOME/cache.d
    if [ ! -d $DEPLOY_CACHE_DIR ]
    then info "Creating cache directory $DEPLOY_CACHE_DIR/ for downloads"
	 mkdir $DEPLOY_CACHE_DIR ||die
    fi
  fi
}

function checkSiteDir {
  [[ -d $HOME/.site.d ]] || mkdir $HOME/.site.d
}
  

function uploadVagrantFile {
  info "Creating VagrantFile for server type $ServerType"
  ServerIP=$(grep $ServerType /etc/hosts | sed 's/[0-9] .*//' |head -1)
  ServerMemory=$(grep $ServerType $HostFile |grep 'deploy_mem:' | sed 's/.*deploy_mem=//' | cut -d\  -f1)
  [[ -n $ServerMemory ]] || ServerMemory=$DEFAULT_MEMORY
  ServerCpu=$(grep $ServerType $HostFile |grep 'deploy_cpu=' | sed 's/.*deploy_cpu=//' | cut -d\  -f1)
  [[ -n $ServerCpu ]] || ServerCpu=$DEFAULT_CPU
  cat $DEPLOY_ANSIBLE/VagrantFile | \
      sed -e "s/~ServerType~/$ServerType/g" \
	  -e "s/~ServerCount~/$ServerCount/g" \
	  -e "s/~ServerMemory~/$ServerMemory/g" \
	  -e "s/~ServerCpu~/$ServerCpu/g" \
	  -e "s/~Domain~/$Domain/g" \
	  -e "s|~VagrantData~|$DEPLOY_VAGRANT|g" \
	  -e "s/~ServerIp~/$ServerIP/g" >VagrantFile || die
  
  info "Uploading VagrantFile to $VAGRANT_PROVIDER host"
  sftp $HostIp:/$ServerType <<<$'put VagrantFile' >/dev/null || die
}

function checkVagrant {
  VagrantStatus=$HOME/.vagrant
  [[ -n $DEPLOY_VAGRANT ]] || DEPLOY_VAGRANT="E:/Vagrant"
  sftp $HostIp:/id_rsa.pub id_rsa.tmp 1>/dev/null 2>&1
  if [ $? -ne 0 ]
  then info "Uploading id_rsa.pub to $VAGRANT_PROVIDER host"
       pushd $HOME/.ssh >/dev/null
       sftp $HostIp:/ <<<$'put id_rsa.pub' >/dev/null || die
       popd >/dev/null
  else rm -f id_rsa.tmp
  fi
  pushd /tmp >/dev/null
  sftp $HostIp:/$ServerType/VagrantFile VagrantFile 1>/dev/null 2>&1
  if [ $? -ne 0 ]
  then info "Creating directory $DEPLOY_VAGRANT/$ServerType on $VAGRANT_PROVIDER host"
       sftp $HostIp <<<$"mkdir $ServerType" >/dev/null || die
       uploadVagrantFile
  else [ $(head -1 VagrantFile | grep -c "\[$ServerCount\]") -eq 1 ] || uploadVagrantFile 
  fi
  rm -f VagrantFile
  popd >/dev/null
}


function refreshVagrant {
  info "Collecting Vagrant global status from $VAGRANT_PROVIDER host"
  ssh $HostIp "vagrant global-status" | grep $VAGRANT_PROVIDER >$VagrantStatus
}

function getVagrantId {
  [ -f $VagrantStatus ] || refreshVagrant
  VagrantId=$(grep " $1 " $VagrantStatus |cut -d\  -f1)
}

function delVagrantId {
  grep -v $VagrantId $VagrantStatus > $VagrantStatus.tmp
  mv $VagrantStatus.tmp $VagrantStatus
}

function checkAnsible {
  which ansible-playbook >/dev/null 2>&1 ||die "Ansible not installed"
  [[ -n $DEPLOY_ANSIBLE ]] || export DEPLOY_ANSIBLE=$HOME/ansible
  [[ -d $DEPLOY_ANSIBLE ]] || die "Directory $DEPLOY_ANSIBLE does not exist"
  HostFile=$DEPLOY_ANSIBLE/hosts
  [[ -f $HostFile ]] || die "No file $HostFile"
  # override Ansible config
  if [[ ! -f $HOME/.ansible.cfg ]]
  then info "Creating file $HOME/.ansible.cfg"
       (cat >$HOME/.ansible.cfg)<<EOF
[defaults]
inventory = $HostFile
remote_user = vagrant
host_key_checking = False
retry_files_enabled = False
hash_behaviour = merge
EOF
  fi
  Playbook=$DEPLOY_ANSIBLE/$1.yml
  [[ -f $Playbook ]] || die "No playbook file $Playbook"
}

function up {
  serv=${1%%.*}
  getVagrantId $serv
  if [[ -n $VagrantId ]]
  then info "Starting up the VM $serv {$VagrantId}"
       ssh $HostIp "vagrant up $VagrantId" || die
  else info "Creating the VMs for $ServerType"
       ssh $HostIp "cmd /C \"set VAGRANT_CWD=$DEPLOY_VAGRANT\\${ServerType} && vagrant up\"" || die
       refreshVagrant
  fi
}

function destroy {
  serv=${1%%.*}
  getVagrantId $serv
  if [[ -n $VagrantId ]]
  then  info "Destroying the VM $serv {$VagrantId}"
	ssh $HostIp "vagrant destroy -f $VagrantId"
	delVagrantId $VagrantId
  else  info "The VM $serv is already destroyed"
  fi
}

function globalStatus {
  info "Vagrant Status"
  getHostIp
  ssh $HostIp "vagrant global-status"
  info "Connection Status"
  echo "TODO"
  exit
}

# ---------------------------------------------------------------

# analyse command line
verbose=""
if [[ ${1:0:2} == -v ]]
then verbose="$1"; shift
fi
[ $# -eq 0 ] && usage
mode=$1
case $mode in
  status)   globalStatus;;
  deploy)   shift;;
  destroy)  shift;;
  shutdown) shift;;
  *)        mode=deploy;;
esac
[ $# -eq 0 ] && usage
pattern=$1
ServerType=$pattern
l=$((${#pattern}-1))
case "${pattern:$l:1}" in
  [1-9]) ServerType=${pattern:0:$l};;
esac

# check the env
getDomain
getHostIp
checkSshConf
checkCacheDir
checkSiteDir
checkAnsible $mode

ServerList=$(ansible-playbook $Playbook --list-hosts --limit "$pattern*.$Domain" | grep $Domain |sort | uniq)
[[ -n $ServerList ]] || die "Cannot find any server matching $pattern"

for server in $ServerList
do ServerCount=$((ServerCount + 1))
done

# up the servers
checkVagrant
for server in $ServerList
do ping -c 1 $server >/dev/null
   alive=$?
   case $mode in
     deploy)  [ $alive -ne 0 ] && up $server;;
     destroy) destroy $server;;
   esac
done
if [[ $mode != destroy ]]
then
  info "Executing ansible playbook $Playbook"
  ansible-playbook $verbose  $Playbook --limit "$pattern*.$Domain"
fi
