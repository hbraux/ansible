#!/bin/bash

DEPLOY_TYPE=$HOME/.deploy.type

f
function die {
    echo "ERROR: $1"
    exit 1
}

function usage {
    echo "$0 <server type>"; exit
}

function vagrantup {
  serv=${1%%.*}
  cache=$HOME/.vagrant.cache
  if [ ! -f $cache ]
  then echo "Collecting Vagrant global status from host $VM_HOST"
       ssh $VM_HOST "vagrant global-status">>$cache
  fi
  id=$(grep " $serv" $cache |cut -d\  -f1)
  [[ -n $id ]] ||die "Cannot find $serv in $cache"
  echo "Starting up the VM $id:$serv with vagrant"
  ssh $VM_HOST "vagrant up $id"
  wait 2
}


function deploy {
    # check if servers are up
    echo "Deploying $servers"
    for server in $servers
    do nc -z  $server 22 >/dev/null
       if [ $? -eq 0 ]
       then echo "VM $server is already running"
       else vagrantup $server
       fi
    done
    echo "Invoking ansible playbook site.yml"
    echo $type > $DEPLOY_TYPE
    ansible-playbook ansible/site.yml -l "$type*"
}

function destroy {
    echo "Undeploying $servers"
    for server in $servers
    do nc -z  $server 22 >/dev/null
       [ $? -eq 0 ] && vagrantdestroy $server
    done
    rm -f $DEPLOY_TYPE
}

function off {
    echo "Stopping $servers"
    for server in $servers
    do nc -z  $server 22 >/dev/null
       [ $? -eq 0 ] && ssh vagrant@$server '/sbin/shutdown -h now'
    done
    rm -f $DEPLOY_TYPE
}


[ $# -ne 0 ] || usage
[[ -n $VM_HOST ]] || die "\$VM_HOST undefined"
nc -z  $VM_HOST 22 >/dev/null|| die "Port 22 not opened on $VM_HOST"

type=$1
mode=deploy
if [ $type == off -o  $type == destroy ]
then [[ -f $DEPLOY_TYPE ]] || die "Nothing to stop"
     mode=$type
     type=$(cat $DEPLOY_TYPE)
else
    if [ -f $DEPLOY_TYPE ]
    then curr=$(cat $DEPLOY_TYPE)
	 [ $curr == $type ] || die "Deployment $curr is already active"
    fi
fi
 
[ $(egrep -c " $type[1-9][.]" /etc/hosts) -ne 0 ] \
    || die "Cannot find any server of type $type in /etc/hosts"
servers=$(grep " $type" /etc/hosts |awk '{ print $2}')


case $mode in
    deploy)   deploy;;
    off)      off;;
    destroy)  destroy;;
esac



