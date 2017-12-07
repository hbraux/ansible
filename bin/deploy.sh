#!/bin/bash

# Constants
DEPLOY_DIR=$HOME/.deploy.d
DEPLOY_CACHE=$DEPLOY_DIR/cache
DEPLOY_ANSIBLE=$HOME/ansible

# variables
declare VagrantId

function die {
    echo "DEPLOY: ERROR: $1"
    exit 1
}
function info {
    echo "DEPLOY: $1"
}

function usage {
    echo "$0 [-s] <server type>"; exit
}

function get_vagrantId {
  if [ ! -f $DEPLOY_CACHE ]
  then info "Collecting Vagrant global status from host $VM_HOST"
       ssh $VM_HOST "vagrant global-status" >>$DEPLOY_CACHE
  fi
  VagrantId=$(grep " $1 " $DEPLOY_CACHE |cut -d\  -f1)
  [[ -n $VagrantId ]] ||die "Cannot find $1 in cache"
}

function up {
  serv=${1%%.*}
  get_vagrantId $serv
  info "Starting up the VM $VagrantId:$serv with vagrant"
  ssh $VM_HOST "vagrant up $VagrantId"
}

function destroy {
  serv=${1%%.*}
  get_vagrantId $serv
  info "Destroying the VM $VagrantId:$serv with vagrant"
  ssh $VM_HOST "vagrant destroy -f $VagrantId" 
}

[ $# -ne 0 ] || usage
[[ -n $VM_HOST ]] || die "\$VM_HOST undefined"
nc -z  $VM_HOST 22 >/dev/null|| die "Port 22 not opened on $VM_HOST"

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
       deploy)    up $server;;
       destroy)   [ $alive -eq 0 ] && destroy $server;;
   esac
done
playbook=$DEPLOY_ANSIBLE/$mode.yml
[ -f $playbook ] && ansible-playbook $playbook -l "$type*"


