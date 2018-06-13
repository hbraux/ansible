#!/bin/bash
# General purpose infra management tool (to be run on Centos/7)
# * install local (admin) environment
# * deploy and manage VM on vagrant/VirtualBox
# Prerequisites (windows)
# 1) install VirtualBox, Vagrant, and Freesshd with SFTP 
# 2) install Vagrant boxes for CentOS7 and Alpine3.6 

TOOL_NAME=infra
TOOL_VERS=0.0.4

###############################################################################
# BEGIN: common.sh 2.3
###############################################################################
# Warning versions 2.x are not compatible with 1.x

[[ -n $TOOL_NAME ]] || TOOL_NAME=${0/.sh/}

# -----------------------------------------------------------------------------
# Shell Colors
# -----------------------------------------------------------------------------
declare BLACK="\e[m"
declare RED="\e[1;31m"
declare GREEN="\e[0;32m"
declare BLUE="\e[0;34m"
declare PURPLE="\e[1;35m"
declare BOLD="\e[1;30m"

# -----------------------------------------------------------------------------
# Global variables that can be used anywhere
# -----------------------------------------------------------------------------

# Temporary File and Directory (purged on exit)
declare TmpFile=$HOME/tmp.${TOOL_NAME}_f$$
declare TmpDir=$HOME/tmp.${TOOL_NAME}_d$$

# Log file (appending)
declare LogFile=${TOOL_NAME}.log
# by defaults logs are in current directory unless there's a logs directory
[[ -d $HOME/logs ]] && LogFile=$HOME/logs/$LogFile

# command line parameters
declare Command=
declare Arguments=

# -----------------------------------------------------------------------------
# Internal variables (reserved for common part)
# -----------------------------------------------------------------------------

# file cheksum, updated when commiting in Git
_MD5SUM="c20e938c5093cba716cd3f746585497e"

# config file
declare _CfgFile=$(dirname $0)/.${TOOL_NAME}.cfg

# command line Options
declare -A _Opts

# -----------------------------------------------------------------------------
# Log functions
# -----------------------------------------------------------------------------
# logging is by default to stdout, unless -L is specified

function _log {
  level=$1
  shift
  dt=$(date +'%F %T')
  echo -e "$level\t$dt\t$*" >>$LogFile
}

function debug {
  [[ ${_Opts[D]} -eq 1 ]] || return
  [[ ${_Opts[L]} -eq 1 ]] && _log DEBUG $* && return
  echo -e "${BLUE}# $*${BLACK}"
}
function info {
  [[ ${_Opts[L]} -eq 1 ]] && _log INFO $* && return
  echo -e "${BOLD}$*${BLACK}"
}
function warn {
  [[ ${_Opts[L]} -eq 1 ]] && _log WARN $* && return
  echo -e "${PURPLE}WARNING: $*${BLACK}"
}
function error {
  [[ ${_Opts[L]} -eq 1 ]] &&  _log ERROR $* 
  # always print errors to stdout
  echo -e "${RED}ERROR: $*${BLACK}"
}

# -----------------------------------------------------------------------------
# quit and die functions
# -----------------------------------------------------------------------------

function quit {
  if [[ $# -eq 0 ]]
  then exitcode=0
  else exitcode=$1
  fi
  [[ -f $TmpFile ]] && rm -f $TmpFile
  [[ -d $TmpDir ]] && rm -fr $TmpDir
  exit $exitcode
}

function die {
  if [[ $# -eq 0 ]]
  then error "command failed"
  else error "$*"
  fi
  quit 1
}

# -----------------------------------------------------------------------------
# internal functions
# -----------------------------------------------------------------------------

# load config file and check expected variables 
function _loadcfg {
  if [[ -f $_CfgFile ]]
  then 
     # check that syntax is consistent
     [[ $(egrep -v '^#' $_CfgFile | egrep -v '^[ ]*$' | egrep -vc '^[A-Z_]*_=') -eq 0 ]] || die "Config file $_CfgFile is not correct"
     # load by sourcing it (stop on error)
     set -e 
     . $_CfgFile 
     set +e
  fi
}

# set supported options 
function _setopts {
  for ((i=0; i<${#1}; i++ ))
  do _Opts[${1:$i:1}]=0
  done
  # option Debug (-D) and Log (-L) are always supported
  _Opts[D]=0
  _Opts[L]=0
}

# read options -X in command line
function _readopts {
  # ignore arguments --xxx
  [[ ${1:0:2} == -- ]] && return 1
  if [[ ${1:0:1} == - ]]
  then
    for ((i=1; i<${#1}; i++ ))
    do o=${1:$i:1}
       [[ -n ${_Opts[$o]} ]] || die "option -$o not supported by $TOOL_NAME"
       _Opts[$o]=1
    done
  else return 1
  fi 
}

# display tool name and version
function _about {
  suffix=""
  [[ $(egrep -v '^_MD5SUM=' $0 | /usr/bin/md5sum | sed 's/ .*//') \
      != $_MD5SUM ]] && suffix=".draft"
  echo "# $TOOL_NAME $TOOL_VERS$suffix"
}

# -----------------------------------------------------------------------------
# public functions
# -----------------------------------------------------------------------------

# opt X check if option -X was set (return 0 if true) 
function opt {
  if [[ -z ${_Opts[${1}]} ]]
  then echo -e "${RED}CODE ERROR: missing option -$1 in init${BLACK}"; exit 1
  fi
  [[ ${_Opts[${1}]} -eq 1 ]] || return 1
}


# analyse command line and set $Command $Arguments and options
# the first arguments are supported options, the second $@ 
function init {
  _about
  if [[ ${1:0:1} == - ]]
  then _setopts ${1:1} ; shift
  fi
  [[ $# -eq 0 ]] && usage
  _loadcfg
  cmdline=$@
  Command=$1
  shift
  # read options (support -abc but also -a -b -c)
  while _readopts $1
  do shift ;done
  Arguments=$@
  opt L && _log INFO "COMMAND: $TOOL_NAME.sh $cmdline"
}


###############################################################################
# END: common.sh
###############################################################################

# ------------------------------------------
# Constants
# ------------------------------------------

VAGRANT_PROVIDER=virtualbox
DEFAULT_MEMORY=1024
DEFAULT_CPU=1
DEFAULT_OS=centos/7

# ------------------------------------------
# Parameters (loaded from Config file)
# ------------------------------------------

# ------------------------------------------
# Global variables
# ------------------------------------------

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
declare SquidIP

# ------------------------------------------
# usage
# ------------------------------------------

function usage {
  echo "Usage: $TOOL_NAME.sh command [options] arguments*

Options:
  -v : verbose
  -f : force

commands:
 status            : servers status
 deploy  <pattern> : deploy server(s)
 destroy <pattern> : destroy server(s)
 on      <pattern> : start server(s)
 off     <pattern> : shutdown server(s)

 <pattern> is a server hostname (or substring) or an Ansible subset
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
  GitRepo=$(dirname $script)
}
  
function getDomain {
  Domain=$(uname -n)
  Domain=${Domain#*.}
}

function getProxy {
  [[ -n $Proxy ]] && return
  if [[ -n $PROXY_SQUID ]] 
  then Proxy=http://$PROXY_SQUID:${PROXY_PORT-3128}  
  fi
  Proxy=${Proxy:-$http_proxy}
  export http_proxy=
  export https_proxy=
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

# ------------------------------------------
# vagrant tools
# ------------------------------------------

function uploadVagrantFile {
  info "Creating VagrantFile for server type $ServerType"
  ServerIP=$(grep "[0-9\.]* $ServerType" /etc/hosts | sed 's/[0-9] .*//' |head -1)
  ServerMemory=$(grep $ServerType $HostFile |grep 'mem=' | sed 's/.*mem=//' | awk '{print $1}')
  [[ -n $ServerMemory ]] || ServerMemory=$DEFAULT_MEMORY
  ServerCpu=$(grep $ServerType $HostFile |grep 'cpu=' | sed 's/.*cpu=//' | awk '{print $1}')
  [[ -n $ServerCpu ]] || ServerCpu=$DEFAULT_CPU
  ServerOS=$(grep $ServerType $HostFile |grep 'os=' | sed 's/.*os=//' | awk '{print $1}')
  [[ -n $ServerOS ]] || ServerOS=$DEFAULT_OS
  getGitRepo
  if [[ -f $GitRepo/desc/$ServerType.txt ]]
  then ServerDesc=$(cat $GitRepo/desc/$ServerType.txt | sed ':a;N;$!ba;s/\n/\\n/g')
  else ServerDesc="VM created with infra.sh"
  fi
  cat $GitRepo/VagrantFile | \
    sed -e "s~@ServerType@~$ServerType~g" \
    -e "s~@ServerCount@~$ServerCount~g" \
    -e "s~@ServerMemory@~$ServerMemory~g" \
    -e "s~@ServerCpu@~$ServerCpu~g" \
    -e "s~@ServerOS@~$ServerOS~g" \
    -e "s~@Domain@~$Domain~g" \
    -e "s~@VagrantData@~$DEPLOY_VAGRANT~g" \
    -e "s~@Description@~$ServerDesc~g" \
    -e "s~@ServerIp@~$ServerIP~g" >VagrantFile || die
  
  info "Uploading VagrantFile to $VAGRANT_PROVIDER host"
  sftp $HostIp:/$ServerType <<<$'put VagrantFile' >/dev/null || die
}

function vagrantCheck {
  [[ -n $DEPLOY_VAGRANT ]] || DEPLOY_VAGRANT="C:/Vagrant"
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
  else vagrantCheck
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

function infraStatus {
  getDomain
  opt f && refreshVagrant
  [[ ! -s $VagrantStatus ]] && refreshVagrant
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
  quit
}

function startServer {
  serv=${1%%.*}
  getVagrantId $serv
  if [[ -n $VagrantId ]]
  then info "Starting $serv with VBoxManage command"
       ssh $HostIp "\"C:\Program Files\Oracle\VirtualBox\vboxmanage.exe\" startvm $serv --type headless" ||  die
  else die "$serv is not provisionned"
  fi
}

# ------------------------------------------
# Ansible tools
# ------------------------------------------

function ansibleCheck {
  which ansible-playbook >/dev/null 2>&1 ||die "Ansible not installed"
  getGitRepo
  HostFile=$GitRepo/hosts
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
  Playbook=$GitRepo/$1.yml
  [[ -f $Playbook ]] || die "No playbook file $Playbook"
}


function ansibleRun {
  getDomain
  getHostIp
  checkSshConf
  
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

    ansibleCheck $Command
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
	on) if [ $alive -ne 0 ]
	  then startServer $server
	  runansible=1
	  else warn "$server is already running"
	  fi;;
	deploy)   runansible=1; [ $alive -ne 0 ] && up $server;;
	destroy) destroy $server;;
	off)    if [ $alive -eq 0 ]
	  then runansible=1
	  else warn "$server is already down"
	  fi;;
      esac
    done
    if [[ $runansible -eq 1 ]]
    then
      opts=""
      opt v && opts="-vvv"
      info "\$ ansible-playbook $Playbook --limit $pattern*.$Domain"
      ansible-playbook $opts $Playbook --limit "$pattern*.$Domain"
    fi
    
  done
}


# ------------------------------------------
# Command Line
# ------------------------------------------

# analyse command line
init -fv $@

case $Command in
  help)     usage;;
  status)   infraStatus;;
  on)       ansibleRun $Arguments;;
  off)      ansibleRun $Arguments;;
  deploy)   ansibleRun $Arguments;;
  destroy)  ansibleRun $Arguments;;
  *)        die "Unknown command $Command "
esac

quit
