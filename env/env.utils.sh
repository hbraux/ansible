# BASH Utils (prompts, tools, helper)

# -----------------------------------------------------------------------------
# Internal functions
# -----------------------------------------------------------------------------
function _info {
  echo -e "\e[1;30m$*\e[m"
}

function _error {
  echo -e "\e[1;31m$*\e[m"
}

function _isfile {
  [[ -f $1 ]] && return 0
  _error "Missing file $1"
  return 1
}
  

# -----------------------------------------------------------------------------
# Java Helpers
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Git helper
# -----------------------------------------------------------------------------
function gpush {
  find . -name "*~" -exec rm {} \;
  comments="$1"
  [[ -n $comments ]] || comments="no comments"
  git add --all
  git commit -m "$comments"
  git push
}

# -----------------------------------------------------------------------------
# SQL helper
# -----------------------------------------------------------------------------
function sql  {
  _isfile $HOME/.orapw || return 1
  if [[ ${1:0:1} != @ ]]
  then user=$1; shift
  else user=""
  fi
  conn=$(egrep "^${ORACLE_SID:-none} ${user}" $HOME/.orapw | head -1 | awk '{print$2}')
  [[ -n $conn ]] || return 1
  conn="$conn@$ORACLE_SID"
  _info "Connecting as ${conn%/*}"
  $ORACLE_HOME/bin/sqlplus "${conn}" $@
}

# -----------------------------------------------------------------------------
# Convertions helper
# -----------------------------------------------------------------------------

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
  findJar avro-hbase jar-with-dependencies || return 1
  asvc=$(ls -t *.asvc | head -1)
  [[ -f $asvc ]] || return 1
  echo "Using Schema file $asvc"
  java -Dlog4j.configuration=file:log4j.properties -jar $_Jar json2hbase $*
}

function csv2json {
  json=${1/.csv/.json}
  row=0
  while IFS=$'\n\r' read -r line
  do if [[ $row -eq 0 ]]
    then sep=$(sed -e 's/^[A-Za-z0-9]*\(.\).*/\1/' <<<$line)
         IFS="$sep" read -ra head_items <<<$line
	 >$json
    else IFS="$sep" read -ra line_items <<<$line
         printf "{" >>$json
         col=0
         for item in ${line_items[@]}
	 do printf "\"${head_items[${col}]}\":" >>$json
           case $item in
             \"\")    printf "null" >>$json;;
             \"*\")   printf "$item" >>$json;;
             [0-9]*.[0-9]*) printf "$item" >>$json;;
             *)       printf "\"$item\"" >>$json;;
	   esac
	   (( col++ ))
           [[ ${col} -lt ${#head_items[@]} ]] && printf "," >>$json \
	     || printf "}" >>$json
         done
	 echo >>$json
    fi
    (( row++ ))
  done <$1
}

# -----------------------------------------------------------------------------
# HDFS Helper 
# -----------------------------------------------------------------------------
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
