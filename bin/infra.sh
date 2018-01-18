#!/bin/bash

# Constants (host)
VAGRANT_PROVIDER=virtualbox
DEFAULT_MEMORY=1024
DEFAULT_CPU=1
DEFAULT_OS=centos/7
DOCKER_REPO=local

# variables
declare ServerType
declare ServerList
declare -i ServerCount=0
declare Playbook
declare HostIp
declare HostFile
declare Domain
declare VagrantStatus=$HOME/.vagrant
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
  echo "Usage: $0 [-<options>] <pattern>* | <command> <pattern>*

Supported options:
  -v[vv] : verbosity
  -r     : refresh status

Supported commands:
 deploy  : deploy server(s). this is the default command
 start   : start server(s)
 shop    : stop server(s)
 destroy : destroy server(s)
 status  : servers status
 build   : build a docker image
 run     : run a docker image
"; exit
}

function getDomain {
  Domain=$(uname -n)
  Domain=${Domain#*.}
}

function getHostIp {
  # check if netstat is there
  which netstat >/dev/null 2>&1
  if [ $? -eq 0 ]
  then HostIp=$(netstat -rn  | grep eth0 | grep '255.255.255' | cut -d\  -f1 | sed 's/.0$/.1/')
  else HostIp=$(ip addr | grep "inet 192." | awk '{ print $4  }' | sed 's/.255$/.1/')
  fi
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

function checkSiteDir {
  [[ -d $HOME/.site.d ]] || mkdir $HOME/.site.d
}
  

function uploadVagrantFile {
  info "Creating VagrantFile for server type $ServerType"
  ServerIP=$(grep $ServerType /etc/hosts | sed 's/[0-9] .*//' |head -1)
  ServerMemory=$(grep $ServerType $HostFile |grep 'mem=' | sed 's/.*mem=//' | awk '{print $1}')
  [[ -n $ServerMemory ]] || ServerMemory=$DEFAULT_MEMORY
  ServerCpu=$(grep $ServerType $HostFile |grep 'cpu=' | sed 's/.*cpu=//' | awk '{print $1}')
  [[ -n $ServerCpu ]] || ServerCpu=$DEFAULT_CPU
  ServerOS=$(grep $ServerType $HostFile |grep 'os=' | sed 's/.*os=//' | awk '{print $1}')
  [[ -n $ServerOS ]] || ServerOS=$DEFAULT_OS
  cat $DEPLOY_ANSIBLE/VagrantFile | \
      sed -e "s~@ServerType@~$ServerType~g" \
	  -e "s~@ServerCount@~$ServerCount~g" \
	  -e "s~@ServerMemory@~$ServerMemory~g" \
	  -e "s~@ServerCpu@~$ServerCpu~g" \
	  -e "s~@ServerOS@~$ServerOS~g" \
	  -e "s~@Domain@~$Domain~g" \
	  -e "s~@VagrantData@~$DEPLOY_VAGRANT~g" \
	  -e "s~@ServerIp@~$ServerIP~g" >VagrantFile || die
  
  info "Uploading VagrantFile to $VAGRANT_PROVIDER host"
  sftp $HostIp:/$ServerType <<<$'put VagrantFile' >/dev/null || die
}

function checkVagrant {
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
  cat $VagrantStatus
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
  else checkVagrant
       info "Creating the VMs for $ServerType using Vagrant"
       ssh $HostIp "cmd /C \"set VAGRANT_CWD=$DEPLOY_VAGRANT\\${ServerType} && vagrant up\"" || die
       refreshVagrant
  fi
}


function destroy {
  serv=${1%%.*}
  getVagrantId $serv
  [[ ${serv:05} == "admin" ]] && die "Cannot destroy an admin server"
  if [[ -n $VagrantId ]]
  then  info "Destroying the VM $serv {$VagrantId}"
	ssh $HostIp "vagrant destroy -f $VagrantId"
	delVagrantId $VagrantId
  else  info "The VM $serv is already destroyed"
  fi
}

function globalStatus {
  if [[ $1 -eq 1 ]]
  then refreshVagrant
  else [[ -f $VagrantStatus ]] || refreshVagrant
  fi
  info "Servers Status"
  for serv in $(cat $VagrantStatus | awk '{print $2}')
  do getVagrantId $serv
     server=$serv.$Domain
     ping -c1 $server >/dev/null
     if [ $? -eq 0 ]
     then echo -e "$serv {$VagrantId}\tRUNNING"
     else echo -e "$serv {$VagrantId}\tDOWN"
     fi
  done
}

function start {
  serv=${1%%.*}
  getVagrantId $serv
  if [[ -n $VagrantId ]]
  then info "Starting $serv with VBoxManage command"
       ssh $HostIp "\"C:\Program Files\Oracle\VirtualBox\vboxmanage.exe\" startvm $serv --type headless" ||  die
  else die "$serv is not provisionned"
  fi
}

function checkDocker {
  which docker >/dev/null 2>&1 ||die "Docker not installed"
  [[ -n $DEPLOY_DOCKER ]] || export DEPLOY_DOCKER=$HOME/docker
  [[ -d $DEPLOY_DOCKER ]] || die "Directory $DEPLOY_DOCKER does not exist"
  [[ -n $PROXY ]] || PROXY=http://$(grep $PROXY_HOST /etc/hosts | cut -d\  -f1):${PROXY_PORT-3128}
}

function build {
  [ $# -eq 0 ] && usage
  img=$1
  checkDocker
  id=$(docker images -q $DOCKER_REPO/$img)
  if [[ -n $id ]]
  then info "Image $DOCKER_REPO/$img [$id] already built"; return
  fi
  [ -d $DEPLOY_DOCKER/$img ] ||die "Directory $DEPLOY_DOCKER/$img does not exist"
  docker build -t $DOCKER_REPO/$img --build-arg PROXY=$PROXY $DEPLOY_DOCKER/$img
}

function run {
  [ $# -eq 0 ] && usage
  img=$1
  checkDocker
}
  
# ---------------------------------------------------------------

# check the env
getDomain
getHostIp
checkSshConf
checkSiteDir

# analyse command line
verbose=""
if [[ ${1:0:2} == -v ]]
then verbose="$1"; shift
fi
refresh=0
if [[ ${1} == -r ]]
then refresh=1; shift
fi

[ $# -eq 0 ] && usage
mode=$1
case $mode in
  build)    build $2; exit;;
  run)      run $2; exit;;
  status)   globalStatus $refresh; exit;;
  deploy)   shift;;
  destroy)  shift;;
  start)    shift;;
  stop)     shift;;
  *)        mode=deploy;;
esac
[ $# -eq 0 ] && usage

# loop on pattern
while [ $# -gt 0 ]
do
pattern=$1
shift  
ServerType=$pattern
l=$((${#pattern}-1))
case "${pattern:$l:1}" in
  [1-9]) ServerType=${pattern:0:$l};;
esac

checkAnsible $mode

ServerList=$(ansible-playbook $Playbook --list-hosts --limit "$pattern*.$Domain" | grep $Domain |sort | uniq)
[[ -n $ServerList ]] || die "Cannot find any server matching $pattern"

for server in $ServerList
do ServerCount=$((ServerCount + 1))
done


runansible=0
for server in $ServerList
do ping -c1 $server >/dev/null
   alive=$?
   case $mode in
     start)   if [ $alive -ne 0 ]
	      then start $server
		   runansible=1
	      else info "$server is already started"
	      fi;;
     deploy)   runansible=1; [ $alive -ne 0 ] && up $server;;
     destroy) destroy $server;;
     stop)    if [ $alive -eq 0 ]
	      then runansible=1
	      else info "$server is already stopped"
	      fi;;
   esac
done
if [[ $runansible -eq 1 ]]
then
  info "Executing ansible playbook $Playbook"
  ansible-playbook $verbose  $Playbook --limit "$pattern*.$Domain"
fi

# end of loop
done
