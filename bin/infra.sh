#!/bin/bash
# General purpose infra management tool (to be run on Centos/7)
# * install local (admin) environment
# * deploy and manage VM on vagrant/VirtualBox
# * build and run Docker images
# Prerequisites (windows)
# 1) install VirtualBox, Vagrant, and Freesshd with SFTP 
# 2) install Vagrant boxes for CentOS7 and Alpine3.6 

TOOL_NAME=infra
TOOL_VERS=0.1

##################################################
# BEGIN: common.sh 1.7
##################################################
# expect TOOL_NAME and TOOL_VERS to be defined in header
[[ -n $TOOL_NAME ]] || TOOL_NAME=$0

# config file
declare CfgFile=$(dirname $0)/.${TOOL_NAME}.cfg

# tmp file and dir to be used in the code
declare TmpFile=$HOME/tmp.${TOOL_NAME}_f$$
declare TmpDir=$HOME/tmp.${TOOL_NAME}_d$$

# command line options
declare -A _Opts

# colors
declare Black="\e[m"
declare Red="\e[0;31m"
declare Green="\e[0;32m"
declare Blue="\e[0;34m"
declare Purple="\e[0;35m"

# log functions
function debug {
  opt D && echo -e "${Blue}# $*${Black}"
}
function info {
  echo -e "${Blue}$*${Black}"
}
function warn {
  echo -e "${Purple}WARNING: $*${Black}"
}
function error {
  echo -e "${Red}ERROR: $*${Black}"
}

# quit: replace exit. cleanup tmp
function quit {
  if [ $# -eq 0 ]
  then exitcode=0
  else exitcode=$1
  fi
  [[ -f $TmpFile ]] && rm -f $TmpFile
  [[ -d $TmpDir ]] && rm -fr $TmpDir
  exit $exitcode
}

# die: quit with error message
function die {
  if [[ $# -eq 0 ]]
  then error "command failed"
  else error "$*"
  fi
  quit 1
}

# load config file and check expected variables 
function load_cfg {
  if [ -f $CfgFile ]
  then 
     . $CfgFile || die "cannot load $CfgFile"
     for var in $*
     do eval "val=\$$var"
        [[ -z $val ]] && die "cannot find $var in file $Cfgfile"
     done
  else [ $# -eq 0 ] || die "file $CfgFile is missing"
  fi
}

# read options -x in command line
function read_opts {
  if [[ ${#_Opts[@]} -eq 0 ]]
  then for ((i=1; i<${#1}; i++ ))
       do _Opts[${1:$i:1}]=0
       done
       # option Debug (-D) is always supported
      _Opts[D]=0
  fi
  # ignore options --param
  [[ ${2:0:2} == '--' ]] && return 1
  if [[ ${2:0:1} == '-' ]]
  then [[ -n ${_Opts[${2:1}]} ]] || die "option $2 not supported"
       _Opts[${2:1}]=1
  else return 1
  fi 
}

# check if option -x was set
function opt {
  [[ -n ${_Opts[${1}]} ]] || die "(bash) missing option -$1 in read_opts"
  [[ ${_Opts[${1}]} -eq 1 ]] || return 1
}


# file cheksum, updated when commiting in Git
_MD5SUM="d2e3fe7995de5d5790c17b372a3ba84c"

# about display tool name and version
function about {
  suffix=""
  [[ $(egrep -v '^_MD5SUM=' $0 | /usr/bin/md5sum | sed 's/ .*//') \
      != $_MD5SUM ]] && suffix=".draft"
  echo "$TOOL_NAME $TOOL_VERS$suffix"
}

##################################################
# END: common.sh
##################################################

# ------------------------------------------
# Constants
# ------------------------------------------

VAGRANT_PROVIDER=virtualbox
DEFAULT_MEMORY=1024
DEFAULT_CPU=1
DEFAULT_OS=centos/7
DOCKER_REPO=local

# ------------------------------------------
# Global variables
# ------------------------------------------

declare Command
declare GitRepo
declare Proxy
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


# ------------------------------------------
# usage
# ------------------------------------------

function usage {
  echo "
Usage: $TOOL_NAME.sh [-<options>] <command> <pattern>*

Supported options:
  -v   : verbose
  -r   : refresh status

Supported commands:
 env     : setup local env
 deploy  : deploy server(s). this is the default optional command 
 start   : start server(s)
 shop    : stop server(s)
 destroy : destroy server(s)
 status  : servers status
 build   : build a docker image
 run     : run a docker image
"
  quit
}

# ------------------------------------------
# local env tools
# ------------------------------------------

function getGitRepo {
  [[ -n $GitRepo ]] && return
  script=$0
  [ -L $script ] && script=$(readlink $script) 
  GitRepo=$(cd $(dirname $script)/.. ; pwd)
}
  
function getDomain {
  Domain=$(uname -n)
  Domain=${Domain#*.}
}

function getProxy {
  [[ -n $PROXY_HOST ]] && Proxy=http://$(grep $PROXY_HOST /etc/hosts | cut -d\  -f1):${PROXY_PORT-3128}  
}

function getHostIp {
  [[ -n $HostIp ]] && return
  # check if netstat is there
  which netstat >/dev/null 2>&1
  if [ $? -eq 0 ]
  then HostIp=$(netstat -rn  | grep eth0 | grep '255.255.255' | cut -d\  -f1 | sed 's/.0$/.1/')
  else HostIp=$(ip addr | grep "inet 192." | awk '{ print $4  }' | sed 's/.255$/.1/')
  fi
  nc -w 1 $HostIp 22 </dev/null >/dev/null \
    || die "port 22 not opened on $VAGRANT_PROVIDER $HostIp -> start freeSSHd!"
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
  [[ -d $HOME/site.d ]] || mkdir $HOME/site.d
}

function setupEnv {
  getGitRepo
  mkdir -p $HOME/bin
  mkdir -p $HOME/site.d
  # environment files
  if [[ ! -d $HOME/env.d ]]
  then mkdir $HOME/env.d
       for f in $(ls $GitRepo/env/env*.sh)
       do info "Installing ${f##*/} in $HOME/env.d/"
	  ln -fs $f $HOME/env.d/
       done
  fi
  # infra files
  for f in $(ls $GitRepo/bin/*.sh)
  do info "Installing ${f##*/} in $HOME/bin"
     ln -fs $f $HOME/bin
  done
  # update bashrc
  grep PS1 $HOME/.bashrc >/dev/null
  if [ $? -ne 0 ]
  then info "Updating .bashrc"
       cp $GitRepo/env/bashrc $HOME/.bashrc 
  fi
  info "Relog if needed"
}


# ------------------------------------------
# vagrant tools
# ------------------------------------------

function uploadVagrantFile {
  info "Creating VagrantFile for server type $ServerType"
  ServerIP=$(grep $ServerType /etc/hosts | sed 's/[0-9] .*//' |head -1)
  ServerMemory=$(grep $ServerType $HostFile |grep 'mem=' | sed 's/.*mem=//' | awk '{print $1}')
  [[ -n $ServerMemory ]] || ServerMemory=$DEFAULT_MEMORY
  ServerCpu=$(grep $ServerType $HostFile |grep 'cpu=' | sed 's/.*cpu=//' | awk '{print $1}')
  [[ -n $ServerCpu ]] || ServerCpu=$DEFAULT_CPU
  ServerOS=$(grep $ServerType $HostFile |grep 'os=' | sed 's/.*os=//' | awk '{print $1}')
  [[ -n $ServerOS ]] || ServerOS=$DEFAULT_OS
  getGitRepo
  cat $GitRepo/ansible/VagrantFile | \
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
  getHostIp
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
  else  warn "The VM $serv is already destroyed"
  fi
}

function globalStatus {
  getDomain
  opt r && refreshVagrant
  [[ -f $VagrantStatus ]] || refreshVagrant
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

# ------------------------------------------
# docker tools
# ------------------------------------------

function checkDocker {
  which docker >/dev/null 2>&1 || die "Docker not installed"
}

function build {
  [ $# -eq 0 ] && usage
  img=$1
  checkDocker
  getGitRepo
  getProxy
  id=$(docker images -q $DOCKER_REPO/$img)
  if [[ -n $id ]]
  then warn "Image $DOCKER_REPO/$img [$id] already built"; return
  fi
  dockerdir=$GitRepo/docker/$img
  [ -d $dockerdir ] ||die "Directory $dockerdir does not exist"
  docker build -t $DOCKER_REPO/$img --build-arg http_proxy=$Proxy $dockerdir
}

function run {
  [ $# -eq 0 ] && usage
  img=$1
}


# ------------------------------------------
# Ansible tools
# ------------------------------------------

function checkAnsible {
  which ansible-playbook >/dev/null 2>&1 ||die "Ansible not installed"
  getGitRepo
  HostFile=$GitRepo/ansible/hosts
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
  Playbook=$GitRepo/ansible/$1.yml
  [[ -f $Playbook ]] || die "No playbook file $Playbook"
}


function runAnsible {
  getDomain
  getHostIp
  checkSshConf
  checkSiteDir
  
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

    checkAnsible $Command

    ServerList=$(ansible-playbook $Playbook --list-hosts --limit "$pattern*.$Domain" | grep $Domain |sort | uniq)
    [[ -n $ServerList ]] || die "Cannot find any server matching $pattern"
    
    for server in $ServerList
    do ServerCount=$((ServerCount + 1))
    done

    runansible=0
    for server in $ServerList
    do ping -c1 $server >/dev/null
      alive=$?
      case $Command in
	start)   if [ $alive -ne 0 ]
	  then start $server
	  runansible=1
	  else warn "$server is already started"
	  fi;;
	deploy)   runansible=1; [ $alive -ne 0 ] && up $server;;
	destroy) destroy $server;;
	stop)    if [ $alive -eq 0 ]
	  then runansible=1
	  else warn "$server is already stopped"
	  fi;;
      esac
    done
    if [[ $runansible -eq 1 ]]
    then
      info "Executing ansible playbook $Playbook"
      ansible-playbook $Playbook --limit "$pattern*.$Domain"
    fi
    
  done
}


# ------------------------------------------
# Command Line
# ------------------------------------------

about

while read_opts -r $1
do shift ;done

[ $# -eq 0 ] && usage
# load config file if any
load_cfg

[ $# -eq 0 ] && usage
Command=$1
case $Command in
  env)      setupEnv; exit;;
  build)    build $2; exit;;
  run)      run $2; exit;;
  status)   globalStatus; exit;;
  deploy)   shift;;
  destroy)  shift;;
  start)    shift;;
  stop)     shift;;
  *)        Command=deploy;; # if no command is provided, assuming deploy
esac
[ $# -eq 0 ] && usage

runAnsible $*
