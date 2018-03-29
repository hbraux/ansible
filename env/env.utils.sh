# custom prompt
PS1='\[\033[1;32m\]\u@\h\[\033[0;34m\][$ORACLE_SID]:\w \$ \[\033[0m\]'

# aliases
alias h=history
alias rmtilde='find . -name "*~" -exec rm {} \;'
alias sf="$HOME/bin/syncFile.sh"
alias off='sudo poweroff'
alias infra="$HOME/bin/infra.sh"
alias vps='sudo  systemctl start stunnel.service ; ssh -p8443 localhost'

# find a Java class ($1) in a directory ($2)
function findClass {
  for i in  $2/*.jar
  do jar tvf $i | grep "/$1.class" |awk "{ print \"$i --> \" \$8 }"
  done
}

# find a Java Library from its name and set variable _Jar
declare _Jar=
function findJar {
  for dir in $(echo "$HOME/jars $HOME/m2 $HOME/m2")
  do _Jar=$(find $dir -name "$1*$2.jar" | tail -1)
     [[ -f $_Jar ]] && echo "Using library $_Jar" && return 0
  done
  return 1
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

# sqlplus autologin
function sql  {
  if [[ -f $HOME/.orapw ]] 
  then conn=$(egrep "^${ORACLE_SID:-none}" $HOME/.orapw | awk '{print$2}')
       [[ -n $conn ]] && conn="$conn@$ORACLE_SID"
  fi
  $ORACLE_HOME/bin/sqlplus $conn $@
}

# docker image info
alias imgdesc="docker inspect --format='{{range \$k,\$v:=.Config.Labels}}{{\$k}}: {{println \$v}}{{end}}'"

# convertion function
function xml2json {
  findJar saxon || return 1
  xml=$1
  shift
  xsl=$(ls -t *.xsl | head -1)
  [[ -f $xsl ]] || return 1
  echo "Usaging XSLT file $xsl" 
  java -jar $_Jar -t -s:$xml -xsl:$xsl -o:${xml/.xml/.json}  $@
}

function json2avro {
  findJar avro-tools || return 1
  asvc=$(ls -t *.asvc | head -1)
  [[ -f $asvc ]] || return 1
  echo "Using Schema file $asvc" 
  java -Dlog4j.configuration=file:log4j.properties -jar $_Jar fromjson --schema-file $asvc $1  >${1/.json/.avro}
}

function json2hbase {
  findJar avro-util jar-with-dependencies || return 1
  asvc=$(ls -t *.asvc | head -1)
  [[ -f $asvc ]] || return 1
  echo "Using Schema file $asvc"
  java -Dlog4j.configuration=file:log4j.properties -jar $_Jar hbaseput $HBASE_SITE/${asvc%_*} $asvc $1 
}

# hdfs commands through edge nodes
function hdfs {
  if [ -x /bin/hdfs ]
  then /bin/hdfs $@ 
  else
    [[ -n $SSH_EDGE ]] || return 1
    ssh $SSH_EDGE hdfs $@
    if [[ $2 == -get ]] 
    then scp $SSH_EDGE:${3##*/} .
         ssh $SSH_EDGE rm ${3##*/}
    fi
  fi
}
export -f hdfs
