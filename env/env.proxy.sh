# proxy handling

# ------------------------------------------
# Environment variables (to set in env.LOCAL.sh)
# ------------------------------------------

# company proxy server (mandatory)
export PROXY_HOST

# Squid proxy (optional)
export PROXY_SQUID

# proxy port (optional)
export PROXY_PORT=${PROXY_PORT:-3128}

# No proxy (optional)
export NO_PROXY=${NO_PROXY:-localhost}

# Proxy authentication hosts and string (optional)
export PROXY_AUTH_HOSTS
export PROXY_AUTH_STR


# ------------------------------------------
# local env tools
# ------------------------------------------

function _proxy_auth {
  [[ -n $PROXY_AUTH_HOSTS ]] || return 1
  if [[ -n $NNI && -n $SESAME ]]
  then login="$NNI:$SESAME"
  else
    if [[ ! -f $HOME/.netrc ]] 
    then echo "No file $HOME/.netrc"; return 1
    fi
    egrep -q '^machine proxy' $HOME/.netrc 
    if [[ $? -ne 0 ]]
    then echo "No line 'machine proxy..' in $HOME/.netrc"; return 1
    fi
    login=$(egrep '^machine proxy' $HOME/.netrc | awk '{print $4 ":" $6}')
  fi
  for h in $(echo $PROXY_AUTH_HOSTS) 
  do curl -Iiku $login "http://$h/$PROXY_AUTH_STR"
     [[ $? -eq 0 ]] || echo "Authentification failed on $h"
  done
}


function _proxy_set {
  _proxy_auth
  export http_proxy=http://${1:-$PROXY_HOST}:$PROXY_PORT
  export https_proxy=$http_proxy
  export no_proxy=$NO_PROXY
  echo "http_proxy=$http_proxy"
  echo "https_proxy=$https_proxy"
  echo "no_proxy=$no_proxy"
}

function _proxy_unset {
  export http_proxy=
  export https_proxy=
  export no_proxy=
  echo "http_proxy="
  echo "https_proxy="
}

function _proxy_help {
  echo "Usage:
proxy        : set proxy variables
proxy unset  : unset proxy variables
proxy test   : check proxy connection
proxy squid  : set proxy ro Squid
"
}

function _proxy_test {
  echo "HTTP code 200 must be returned ..."
  curl -si -m2 http://www.google.fr | head -1
}

# ------------------------------------------
# local env tools
# ------------------------------------------

function proxy {
  if [[ $# -eq 0 ]]
  then _proxy_set
  else 
    case $1 in
      u|unset) _proxy_unset;;
      squid)   _proxy_set $PROXY_SQUID;;
      test)    _proxy_test;;
      *)       _proxy_help;;
    esac
  fi
}


