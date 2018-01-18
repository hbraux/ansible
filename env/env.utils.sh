# aliases
alias rmtilde='find . -name "*~" -exec rm {} \;'
alias sf="$HOME/bin/syncFile.sh"
alias off='sudo poweroff'
alias infra="$HOME/bin/infra.sh"

# proxy handling
function _setproxy {
  [[ -n $PROXY_HOST ]] || return
  export http_proxy=http://$PROXY_HOST:${PROXY_PORT-3128}
  export https_proxy=$http_proxy
}

function _unsetproxy {
  export http_proxy=
  export https_proxy=
}

function proxy {
  if [[ -n $PROXY_HOST ]]
  then
     if [[ -n $http_proxy  ]]
     then _unsetproxy
     else _setproxy
     fi
     echo "http_proxy=$http_proxy"
     echo "https_proxy=$https_proxy"
  else echo "ERROR:\$PROXY_HOST is not defined"
  fi
}

# find a Java class
function findClass {
  for i in  $2/*.jar
  do jar tvf $i | grep "/$1.class" |awk "{ print \"$i --> \" \$8 }"
  done
}

# git helper
function gpush {
  find . -name "*~" -exec rm {} \;
  comments="$1"
  [[ -n $comments ]] || comments="no comments"
  git add .
  git commit -m "$comments"
  _setproxy
  git push
}


