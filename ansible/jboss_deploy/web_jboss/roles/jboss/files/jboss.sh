#!/bin/sh
#
# JBoss-eap-5.1 control script
#
# chkconfig: - 80 20
# description: JBoss Eap 5.1 
# processname: jboss-as 
# pidfile: /jboss/jboss-eap-5.1/jboss-as/jboss.pid
# config: $JBOSS_HOME/bin/run.conf

# Source function library.
. /etc/init.d/functions

# Load Java and jboss configuration.
export JAVA_HOME=/jboss/jdk1.6.0_45
export PATH=$JAVA_HOME/bin:$JAVA_HOME/jre/bin:$PATH
export CLASSPATH=.$CLASSPATH:$JAVA_HOME/lib:$JAVA_HOME/jre/lib:$JAVA_HOME/lib/tools.jar
export JBOSS_HOME=/jboss/jboss-eap-5.1/jboss-as
export PATH=$PATH:$JBOSS_HOME/bin
##

# Set the JBoss user
JBOSS_USER=jboss  
export JBOSS_USER 

# Load JBoss AS init.d configuration.
if [ -z "$JBOSS_CONF" ]; then
  JBOSS_CONF="$JBOSS_HOME/bin/run.conf"
fi

[ -r "$JBOSS_CONF" ] && . "${JBOSS_CONF}"

# Set defaults.

if [ -z "$JBOSS_HOME" ]; then
  JBOSS_HOME=/jboss/jboss-eap-5.1/jboss-as
fi
export JBOSS_HOME

if [ -z "$JBOSS_PIDFILE" ]; then
  JBOSS_PIDFILE=$JBOSS_HOME/jboss.pid
fi
export JBOSS_PIDFILE

if [ -z "$STARTUP_WAIT" ]; then
  STARTUP_WAIT=30
fi

if [ -z "$SHUTDOWN_WAIT" ]; then
  SHUTDOWN_WAIT=30
fi


# Get the host's IP address 
INET=("bond0" "eth0" "eth1" "eth2")
INET_HOME=/etc/sysconfig/network-scripts
GET_IP() {
  /sbin/ifconfig $1 | grep "inet addr" | awk '{print $2}' | awk -F ":" '{print $2}'
}
for inet in ${INET[*]}
do
  if [ -e "${INET_HOME}/ifcfg-${inet}" ];then
    if [ "${inet}" == "bond0" ];then
      IP_ADDR=$(GET_IP bond0)
    elif [ "${inet}" == "eth0" ];then
      IP_ADDR=$(GET_IP eth0)
    else
      echo "Geting IP ERROR..."
    fi
  fi
done

if [ -z "$JBOSS_CONSOLE_LOG" ]; then
  JBOSS_CONSOLE_LOG=$JBOSS_HOME/server/web/log/"$IP_ADDR"_server_log
fi

JBOSS_SCRIPT=$JBOSS_HOME/bin/run.sh

prog='jboss'

## Set the start parameters 
PARA="-Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false -Djboss.server.log.threshold=ERROR"

start() {
  echo -n "Starting $prog: "
  if [ -f $JBOSS_PIDFILE ]; then
    read ppid < $JBOSS_PIDFILE
    if [ `ps --pid $ppid 2> /dev/null | grep -c $ppid 2> /dev/null` -eq '1' ]; then
      echo -n "$prog is already running"
      echo
      return 1 
    else
      rm -f $JBOSS_PIDFILE
    fi
  fi
  

  if [ ! -z "$JBOSS_USER" ]; then
      LAUNCH_JBOSS_IN_BACKGROUND=1 $JBOSS_SCRIPT -c web -b $IP_ADDR $PARA  > /dev/null & 
    else
      echo "Please use jboss to start this process."
  fi
  cat /dev/null > $JBOSS_CONSOLE_LOG
  
  count=0
  launched=false

  until [ $count -gt $STARTUP_WAIT ]
  do
    grep '(main) Server startup in*' $JBOSS_CONSOLE_LOG > /dev/null 
    if [ $? -eq 0 ] ; then
      launched=true
      break
    fi 
    sleep 1
    let count=$count+1;
  done
  success 
  echo
  return 0
}

stop() {
  echo -n $"Stopping $prog: "
  count=0;

  if [ -f $JBOSS_PIDFILE ]; then
    read kpid < $JBOSS_PIDFILE
    let kwait=$SHUTDOWN_WAIT

    # Try issuing SIGTERM

    kill -15 $kpid
    until [ `ps --pid $kpid 2> /dev/null | grep -c $kpid 2> /dev/null` -eq '0' ] || [ $count -gt $kwait ]
    do
      sleep 1
      let count=$count+1;
    done

    if [ $count -gt $kwait ]; then
      kill -9 $kpid
    fi
  fi
  rm -f $JBOSS_PIDFILE
  success
  echo
}
log() {
       echo -n $"ShowLoging $IP_ADDR $prog log: "
       tail -f -n200 /jboss/jboss-eap-5.1/jboss-as/server/web/log/"$IP_ADDR"_server_log
}
status() {
  if [ -f $JBOSS_PIDFILE ]; then
    read ppid < $JBOSS_PIDFILE
    if [ `ps --pid $ppid 2> /dev/null | grep -c $ppid 2> /dev/null` -eq '1' ]; then
      echo "$prog is running (pid $ppid)"
      return 0
    else
      echo "$prog dead but pid file exists"
      return 1
    fi
  fi
  echo "$prog is not running"
  return 3
}

case "$1" in
  start)
      start
      ;;
  stop)
      stop
      ;;
  restart)
      $0 stop
      $0 start
      ;;
  status)
      status
      ;;
  log)
      log
      ;;
  *)
      ## If no parameters are given, print which are avaiable.
      echo "Usage: $0 {start|stop|status|restart|reload}"
      exit 1
      ;;
esac
