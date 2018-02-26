# custom prompt
PS1='\[\033[1;32m\]\u@\h:\[\033[1;34m\] \w \$ \[\033[0m\]'

# aliases
alias rmtilde='find . -name "*~" -exec rm {} \;'
alias sf="$HOME/bin/syncFile.sh"
alias off='sudo poweroff'
alias infra="$HOME/bin/infra.sh"
alias vps='sudo  systemctl start stunnel.service ; ssh -p8443 localhost'

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
  git add --all
  git commit -m "$comments"
  git push
}


