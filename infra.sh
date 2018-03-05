#!/bin/bash
# General purpose infra management tool (to be run on Centos/7)
# * install local (admin) environment
# * deploy and manage VM on vagrant/VirtualBox
# * build and run Docker images
# Prerequisites (windows)
# 1) install VirtualBox, Vagrant, and Freesshd with SFTP 
# 2) install Vagrant boxes for CentOS7 and Alpine3.6 

TOOL_NAME=infra
TOOL_VERS=0.0.3


###############################################################################
# BEGIN: common.sh 2.1
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

# command line parameters
declare Command=
declare Arguments=

# -----------------------------------------------------------------------------
# Internal variables (reserved for common part)
# -----------------------------------------------------------------------------

# file cheksum, updated when commiting in Git
_MD5SUM="b254e3b5665a2eed04a7a5e1563e0525"

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
  opt D || return
  opt L && _log DEBUG $* && return
  echo -e "${BLUE}# $*${BLACK}"
}
function info {
  opt L && _log INFO $* && return
  echo -e "${BOLD}$*${BLACK}"
}
function warn {
  opt L && _log WARN $* && return
  echo -e "${PURPLE}WARNING: $*${BLACK}"
}
function error {
  opt L &&  _log ERROR $* 
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
DOCKER_NETWORK=${DOCKER_NETWORK:-udn}  # for DNS purpose

# ------------------------------------------
# Parameters (loaded from Config file)
# ------------------------------------------
DOCKER_PORTS_="server:8080:9080" # example of mapping

# ------------------------------------------
# Global variables
# ------------------------------------------

declare -i DockerCommand=1
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
  echo "Usage: $TOOL_NAME.sh command [options] arguments*

Options:
  -v : verbose
  -f : force

commands:
 env               : setup local env

 status            : servers status
 deploy  <pattern> : deploy server(s)
 destroy <pattern> : destroy server(s)
 on      <pattern> : start server(s)
 off     <pattern> : shutdown server(s)

 <pattern> is a server hostname (or substring) or an Ansible subset

 dock              : docker status (images, containers,.)
 build   <image>   : build a docker image
 [run]   <image>...: run a docker image (run is optional). Add 'help' for info
 stop    <image>   : stop a docker image
 rm      <image>   : remove a docker container (stop it if needed)
 test    <image>   : test a docker image
 logs    <image>   : docker logs
 clean             ! docker clean

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
  then Proxy=http://$(grep $PROXY_SQUID /etc/hosts | cut -d\  -f1):${PROXY_PORT-3128}  
  else [[ -n $PROXY_SQUID ]] && Proxy=http://$(grep $PROXY_SQUID /etc/hosts | cut -d\  -f1):${PROXY_PORT-3128}
  fi
  Proxy=${Proxy:-$http_proxy}
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
  ServerIP=$(grep "[0-9\.]* $ServerType" /etc/hosts | sed 's/[0-9] .*//' |head -1)
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
# docker tools
# ------------------------------------------

# small helper to display the docker command being run
function _docker {
  info "\$ docker $*"
  docker $*
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
  if [[ ! -d $DockerDir ]] 
  then [[ $Command == build ]] && die "no docker repository named '$DockerImg'"
    die "Command '$Command' not supported; and no docker repository named '$DockerImg'"
  fi
  [[ -f $DockerDir/Dockerfile ]] || die "No file $DockerDir/Dockerfile"
}

function dockerBuild {
  getProxy
  id=$(docker images -q ${DockerImg}:latest)
  if [[ -n $id ]]
  then warn "Image $DockerImg [$id] already built"
       opt f || return
       _docker rmi -f $id
  fi
  egrep -q '^VOLUME \[' $DockerDir/Dockerfile && die "$TOOL_NAME does not support VOLUME in JSON format"
  vers=$(egrep -i "^ENV ${DockerImg}[A-Z]*_VERSION" $DockerDir/Dockerfile | awk '{print $3}')
  [[ -n $vers ]] || warn "No VERSION found in Dockerfile"
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
  tags="-t $DockerImg:latest"
  [[ -n $vers ]] && tags="$tags -t $DockerImg:$vers"

  buildargs="--build-arg http_proxy=$Proxy"
  for arg in $(egrep "^ARG " $DockerDir/Dockerfile | sed 's/ARG \([A-Z_]*\)=.*/\1/') 
  do [[ -n ${!arg} ]] && buildargs="$buildargs --build-arg $arg=${!arg}"
  done
  _docker build $tags $buildargs $DockerDir 
  info "$ docker images .."
  docker images --format 'table{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' --filter=reference='*:[0-9]*'
}


function dockerRun {
  args=$*
  if [[ $# -eq 0 && $DockerImg != bash && $DockerImg != python ]]
  then # server mode
      id=$(docker ps -a | grep "$DockerImg\$" | awk '{print $1}')
       if [[ -n $id ]]
       then _docker ps | grep -q "$DockerImg\$"
	    if [ $? -eq 0 ]
	    then warn "Container $DockerImg [$id] already running"
	    else _docker start $id
            fi
	    return
       fi
       opts="-d --name=$DockerImg --network=$DOCKER_NETWORK"
       volume=$(egrep '^VOLUME' $DockerDir/Dockerfile | awk '{print $2}')
       [[ -n $volume ]] && opts="$opts --mount source=${DockerImg}-data,target=$volume"
       for port in $(egrep '^EXPOSE ' $DockerDir/Dockerfile | cut -c 8-)
       do for m in $DOCKER_PORTS_
	  do hport=$(grep $DockerImg:$port <<<$m | cut -d: -f3)
	    [[ -n $hport ]] && opts="$opts -p $hport:$port"
	 done
       done
       for e in $(env |egrep "^${DockerImg^^}_")
       do opts="$opts -e $e"
       done
       # WA for NIFI-4761
       [[ $DockerImg == nifi ]] && opts="$opts -h $DOCKER_HOST"
       args=start
  else # command mode
       opts="-i --rm --network=$DOCKER_NETWORK"
     [[ $DockerTty -eq 1 ]] && opts="-t $opts"       
  fi
  _docker run $opts $DockerImg $args
}

function dockerStop {
  id=$(docker ps  | grep "$DockerImg\$" | awk '{print $1}')
  if [[ -z $id ]]
  then warn "Container $DockerImg not running"
  else _docker stop $id
  fi
}


function dockerRm {
  id=$(docker ps -a | grep "$DockerImg\$" | awk '{print $1}')
  if [[ -z $id ]] 
  then warn "Container $DockerImg not found"
  else _docker ps  | grep -q "$DockerImg\$"
       if [ $? -eq 0 ]
       then _docker stop $id
	    sleep 2 
       fi
       _docker rm $id
       volume=${DockerImg}-data
       docker volume ls | grep -q $volume && _docker volume rm $volume
  fi
}

function dockerStatus {
  dockerCheck
  opt v 
  if [[ $? -eq 0 ]]
  then 
    _docker images
    _docker ps -a
  else 
    info "$ docker images .."
    docker images --format 'table{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' --filter=reference='*:[0-9]*'
    info "$ docker ps .."
    docker ps -a  --format 'table{{.Image}}:{{.Names}}\t{{.ID}}\t{{.Status}}'
  fi
  _docker volume ls
}

function dockerClean {
  dockerCheck
  _docker container prune -f
  for vol in $(docker volume ls -q)
  do grep -q "[0-9a-f]\{64\}" <<<$vol && _docker volume rm $vol
  done
  ids=$(docker images -f "dangling=true" -q)
  [[ -n $ids ]] && _docker rmi -f $ids
  echo
  dockerStatus
}

function dockerTest {
  testfile=$DockerDir/test-server.sh
  [[ -f $testfile ]] || die "No file $testfile"
  dockerRm 
  dockerBuild
  info "\nTesting help\n------------------------------------------"
  dockerRun help || die
  info "\nStarting $DockerImg\n------------------------------------------"
  dockerRun
  # wating 10 sec. for server to start
  sleep 10
  docker ps | grep -q " $DockerImg "
  if [ $? -ne 0 ]
  then docker logs $DockerImg
       die "Server failed to start"
  fi
  # execute test file
  info "\nTesting $DockerImg health\n------------------------------------------"
  DockerTty=0 source $testfile |& tee $TmpFile || die
  grep -q "Exception " $TmpFile
  [[ $? -eq 0 ]] && die 
  # check persistence (volume)
  testfile=$DockerDir/test-volume.sh
  if [[ -f $testfile ]] 
  then info "\nTesting $DockerImg persistence\n------------------------------------------"
       dockerStop
       sleep 1
       dockerRun
       sleep 5
       DockerTty=0 source $testfile  || die
  fi
  dockerRm
  info "\nTESTING OK"
}

function dockerLogs {
  _docker logs $DockerImg
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
      info "\$ ansible-playbook $Playbook --limit $pattern*.$Domain"
      ansible-playbook $Playbook --limit "$pattern*.$Domain"
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
  env)      setupEnv;;
  b|build)  getDockerImg $Arguments; dockerBuild;;
  run)      getDockerImg $Arguments; dockerRun ${Arguments/$DockerImg/};;
  rm)       getDockerImg $Arguments; dockerRm;;
  stop)     getDockerImg $Arguments; dockerStop;;
  test)     getDockerImg $Arguments; dockerTest;;
  l|logs)   getDockerImg $Arguments; dockerLogs;;
  d|dock)   dockerStatus;;
  clean)    dockerClean ;;
  status)   infraStatus;;
  on)       DockerCommand=0;;
  off)      DockerCommand=0;;
  deploy)   DockerCommand=0;;
  destroy)  DockerCommand=0;;
  *) getDockerImg $Command; dockerRun $Arguments;;
esac

[[ $DockerCommand -eq 0 ]] || quit
[ $# -eq 0 ] && usage
ansibleRun $Arguments

quit
