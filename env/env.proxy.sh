# file to be sources to handle proxy

# those variables shall be set ahead 
export NO_PROXY=${NO_PROXY:-localhost}
export PROXY_HOST=${PROXY_HOST:-}
export PROXY_PORT=${PROXY_PORT:-3128}
export PROXY_AUTH_HOSTS=
export PROXY_AUTH_STR=

function _setproxy {
  _authproxy
  export http_proxy=http://$PROXY_HOST:$PROXY_PORT
  export https_proxy=$http_proxy
  export no_proxy=$NO_PROXY
}

function _unsetproxy {
  export http_proxy=
  export https_proxy=
  export no_proxy=
}

function proxy {
  if [[ -z $PROXY_HOST ]]
  then echo "ERROR:\$PROXY_HOST is not defined" ; return
  fi
  if [[ $1 == test ]]
  then echo "HTTP code 200 must be returned ..."
       curl -si -m2 http://www.google.fr | head -1
       return
  fi
  if [[ $1 == unset || $1 == u ]]
  then _unsetproxy
  else _setproxy
  fi
  echo "http_proxy=$http_proxy"
  echo "https_proxy=$https_proxy"
  echo "no_proxy=$no_proxy"
}

function _authproxy() {
  [[ -n $PROXY_AUTH_HOSTS ]] || return
  if [[ ! -f $HOME/.netrc ]] 
  then echo "No file $HOME/.netrc"; return
  fi
  grep -q 'machine proxy' $HOME/.netrc 
  if [[ $? -ne 0 ]]
  then echo "No line 'machine proxy..' in $HOME/.netrc"; return
  fi
  login=$(grep 'machine proxy' $HOME/.netrc | awk '{print $4 ":" $6}')
  for h in $(echo $PROXY_AUTH_HOSTS) 
  do curl -Iiku $login "http://$h/$PROXY_AUTH_STR"
     [[ $? -eq 0 ]] || echo "Authentification failed on $h"
  done
}

