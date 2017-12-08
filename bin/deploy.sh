#!/bin/bash

# Constants
DEPLOY_DIR=$HOME/.deploy.d
DEPLOY_CACHE=$DEPLOY_DIR/cache
DEPLOY_ANSIBLE=$HOME/ansible

# variables
declare VagrantId
declare HostIp

function die {
    echo "DEPLOY: *** ERROR *** $1"
    exit 1
}
function info {
    echo "DEPLOY: $1"
}

function usage {
    echo "$0 [-s] <server type>"; exit
}

function checkSshConf {
    domain=$(uname -n)
    domain=${domain#*.}
    [ -f $HOME/.ssh/config ] || touch $HOME/.ssh/config
    if [ $(grep -c "\*\.$domain" $HOME/.ssh/config) -eq 0 ]
    then info "Updating $HOME/.ssh/config"
	 echo "
Host *.$domain
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null
" >>$HOME/.ssh/config
    fi
} 

function getVagrantId {
  if [ ! -f $DEPLOY_CACHE ]
  then info "Collecting Vagrant global status from host $HostIp"
       ssh $HostIp "vagrant global-status" >>$DEPLOY_CACHE
  fi
  VagrantId=$(grep " $1 " $DEPLOY_CACHE |cut -d\  -f1)
  [[ -n $VagrantId ]] ||die "Cannot find $1 in cache"
}

function getHostIp {
    HostIp=$(netstat -rn  | grep eth0 | grep '255.255.255' | cut -d\  -f1 | sed 's/.0$/.1/')
    
}
function up {
  serv=${1%%.*}
  getVagrantId $serv
  info "Starting up the VM $VagrantId:$serv"
  ssh $HostIp "vagrant up $VagrantId"
}

function destroy {
  serv=${1%%.*}
  getVagrantId $serv
  info "Destroying the VM $VagrantId:$serv with vagrant"
  ssh $HostIp "vagrant destroy -f $VagrantId" 
}

[ $# -ne 0 ] || usage

checkSshConf
getHostIp
nc -w 1 $HostIp 22 </dev/null >/dev/null || die "port 22 not opened on $HostIp"

mkdir -p $DEPLOY_DIR

mode=deploy
if [[ $1 == -s ]]
then mode=shutdown; shift
else if [[ $1 == -D ]]
     then mode=destroy; shift
     fi
fi
type=$1
[ $(egrep -c " $type[1-9][.]" /etc/hosts) -ne 0 ] \
    || die "Cannot find any server of type $type in /etc/hosts"

for server in $(grep " $type" /etc/hosts |awk '{ print $2}')
do ping -c 1 $server >/dev/null
   alive=$?
   case $mode in
       deploy)    [ $alive -ne 0 ] && up $server;;
       destroy)   [ $alive -eq 0 ] && destroy $server;;
   esac
done
playbook=$DEPLOY_ANSIBLE/$mode.yml
[ -f $playbook ] && ansible-playbook $playbook -l "$type*"


