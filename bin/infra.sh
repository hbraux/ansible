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
DOCKER_NETWORK=udn  # user defined network to use DNS

# ------------------------------------------
# Global variables
# ------------------------------------------

declare Command
declare -i DockerCommand=0
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
declare DockerDir
declare DockerImg
declare -i DockerTty=1

# ------------------------------------------
# usage
# ------------------------------------------

function usage {
  echo "
Usage: $TOOL_NAME.sh <command> [-<flags>] <arguments>*

Supported flags:
  -V   : verbose
  -F   : force

Supported commands:
 env               : setup local env

 status            : servers status
 deploy  <pattern> : deploy server(s)
 destroy <pattern> : destroy server(s)
 start   <pattern> : start server(s)
 stop    <pattern> : stop server(s)

 dock              : docker status (images, containers,.)
 clean             ! docker clean
 build   <image>   : build a docker image
 run     <image>.. : run a docker image
 kill    <image>   : stop a docker image
 rm      <image>   : stop and remove a docker container
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
  quit
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

function vagrantCheck {
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
  opt F && refreshVagrant
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
# docker tools
# ------------------------------------------

# small helper to ignore proxy and display the docker command being run
function _docker {
  DockerCommand=1
  info "\$ docker $*"
  http_proxy="" docker $* 
}

function dockerCheck {
  which docker >/dev/null 2>&1 || die "Docker not installed"
  [[ -n $DOCKER_HOST ]] || die "DOCKER_HOST not defined"
  ping -c1 $DOCKER_HOST >/dev/null 2>&1
  [[ $? -eq 0 ]] || die "Docker host $DOCKER_HOST not reachable"
  _docker network ls | grep -q $DOCKER_NETWORK 
  [[ $? -eq 0 ]] || _docker network create --driver bridge $DOCKER_NETWORK || die

}

function getDockerImg {
  [[ $# -eq 0 ]] && usage
  DockerImg=$1
  dockerCheck
  getGitRepo
  DockerDir=$GitRepo/docker/$DockerImg
  [[ -d $DockerDir ]] || die "Command '$Command' not supported; and no docker repository named '$DockerImg'"
  [[ -f $DockerDir/Dockerfile ]] || die "No file $DockerDir/Dockerfile"
}

function dockerBuild {
  getProxy
  id=$(http_proxy="" docker images -q $DockerImg)
  if [[ -n $id ]]
  then warn "Image $DockerImg [$id] already built"
       opt F || return
       _docker rmi -f $id
  fi
  grep -q 'VOLUME \[' $DockerDir/Dockerfile && die "$TOOL_NAME does not support VOLUME in JSON format"
  if [ -f  $DockerDir/TOOLS ]
  then mkdir -p $DockerDir/tools
       for tool in $(cat $DockerDir/TOOLS)
       do [[ -f $HOME/bin/$tool ]] || die "Cannot find $HOME/bin/$tool"
	  diff $HOME/bin/$tool $DockerDir/tools/$tool >/dev/null
	  if [[ $? -ne 0 ]]
	  then info "Updating $DockerDir/tools/$tool"
               cp -f $HOME/bin/$tool $DockerDir/tools/
	  fi
       done
  fi
  _docker build -t $DockerImg --build-arg http_proxy=$Proxy $DockerDir 
  _docker images
}



function dockerRun {
  if [[ $# -eq 0 && $DockerImg != bash ]]
  then id=$(http_proxy="" docker ps -a | grep "$DockerImg\$" | awk '{print $1}')
       if [[ -n $id ]]
       then _docker ps | grep -q "$DockerImg\$"
	    if [ $? -eq 0 ]
	    then warn "Container $DockerImg [$id] already running"
	    else _docker start $id
            fi
	    return
       fi
       opts="-d --name=$DockerImg --network=$DOCKER_NETWORK"
       volume=$(grep VOLUME $DockerDir/Dockerfile | awk '{print $2}')
       [[ -n $volume ]] && opts="$opts --mount source=${DockerImg}-data,target=$volume"
       for port in $(grep "EXPOSE .*/TCP" $DockerDir/Dockerfile | sed 's~EXPOSE \([0-9]\+\)/TCP~\1~')
       do  opts="$opts -p $port:$port"
       done
  else opts="-i --rm --network=$DOCKER_NETWORK"
     [[ $DockerTty -eq 1 ]] && opts="-t $opts"       
  fi
  opt V && export opts="$opts -e VERBOSE=1"
  _docker run $opts $DockerImg $*
}

function dockerKill {
  id=$(http_proxy="" docker ps  | grep "$DockerImg\$" | awk '{print $1}')
  if [[ -z $id ]]
  then warn "Container $DockerImg not running"
  else _docker stop $id
  fi
}


function dockerRm {
  id=$(http_proxy="" docker ps -a | grep "$DockerImg\$" | awk '{print $1}')
  if [[ -z $id ]] 
  then warn "Container $DockerImg not found"
  else _docker ps  | grep -q "$DockerImg\$"
       if [ $? -eq 0 ]
       then _docker stop $id
	    sleep 2 
       fi
       _docker rm $id
       volume=${DockerImg}-data
       http_proxy="" docker volume ls | grep -q $volume && _docker volume rm $volume
  fi
}

function dockerStatus {
  dockerCheck
  _docker images
  _docker ps -a
  _docker volume ls
}

function dockerClean {
  dockerCheck
  _docker container prune -f
  for vol in $(http_proxy="" docker volume ls -q)
  do grep -q "[0-9a-f]\{64\}" <<<$vol && _docker volume rm $vol
  done
}

function dockerTest {
  testfile=$DockerDir/test-server.sh
  [[ -f $testfile ]] || die "No file $testfile"
  dockerRm 
  dockerBuild
  # check --help
  dockerRun --help || die
  dockerRun
  # execute test file
  info "\nTesting $DockerImg Server Status\n------------------------------------------"
  DockerTty=0 SERVER_NAME=$DockerImg source $testfile  || die
  # check persistence (volume)
  testfile=$DockerDir/test-volume.sh
  if [[ -f $testfile ]] 
  then info "\nTesting $DockerImg Server Persistence\n------------------------------------------"
       dockerKill
       dockerRun
       DockerTty=0 SERVER_NAME=$DockerImg source $testfile  || die
  fi
  dockerRm
  info "\nTEST OK"
}
 

# ------------------------------------------
# Ansible tools
# ------------------------------------------

function ansibleCheck {
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


function ansibleRun {
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
	start)   if [ $alive -ne 0 ]
	  then startServer $server
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
      info "\$ ansible-playbook $Playbook --limit $pattern*.$Domain"
      ansible-playbook $Playbook --limit "$pattern*.$Domain"
    fi
    
  done
}


# ------------------------------------------
# Command Line
# ------------------------------------------

about
# load config file if any
load_cfg


[ $# -eq 0 ] && usage
Command=$1
shift
# read opts
while read_opts -FV $1
do shift ;done


case $Command in
  env)      setupEnv;;
  build)    getDockerImg $1; dockerBuild;;
  run)      getDockerImg $1; shift; dockerRun $*;;
  rm)       getDockerImg $1; dockerRm;;
  kill)     getDockerImg $1; dockerKill;;
  test)     getDockerImg $1; dockerTest;;
  dock)     dockerStatus;;
  clean)    dockerClean ;;
  status)   infraStatus;;
  start) ;;
  stop) ;;
  deploy) ;;
  destroy) ;;
  *) getDockerImg $Command; dockerRun $*;;
esac

[[ $DockerCommand -eq 1 ]] && quit
[ $# -eq 0 ] && usage
ansibleRun $*
quit
