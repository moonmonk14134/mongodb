#!/bin/bash

passwdfile=/home/mongod/control/.passwd
ServerType=${1-mongod}
INFO=`grep $ServerType $passwdfile`
var=( $(echo $INFO |cut -d: --output-delimiter=' ' -f2-8 ) )
HOST=${var[0]}
PORT=${var[1]}
MONGOPEM=${var[2]}
ROOTPEM=${var[3]}
USER=${var[4]}
PW=${var[5]}
DB=${var[6]}

#### LEVEL_ALERT=dbops@webmd.net
LEVEL_ALERT=kchang@webmd.net
HOSTNAME=`hostname -s`
LOG=~/admin/log/Repl_mon.out
TFile1=/tmp/tmp1 ; cat /dev/null >$TFile1

mongo --quiet --ssl --sslAllowInvalidCertificates --host $HOST --port=$PORT  --sslPEMKeyFile=/etc/ssl/$MONGOPEM --sslCAFile=/etc/ssl/$ROOTPEM  -u $USER -p $PW  --authenticationDatabase $DB  << EOF >> $TFile1
var isMaster = rs.isMaster();
var me = isMaster.me;

if( (!isMaster.ismaster) && isMaster.secondary) { 
    var status = rs.status();
    var master = isMaster.primary;
    var masterOptime = 0;
    var masterOptimeDate = 0;
    var myOptime = 0;
    var myOptimeDate = 0;
    for(var i = 0 ; i < status.members.length ; i++) {
        var member = status.members[i];
        if(member.name == me) 
        {
            if(member.stateStr == "SECONDARY") {
                myOptime = member.optime.ts.getTime();
                myOptimeDate = member.optimeDate.getDate();
            }
            else {
                print(me + ' is out of sync ' + member.stateStr);
                break;
            }
        }
        else if(member.stateStr == "(not reachable/healthy)") {
            print(member.name + ' is not reachable/healthy. ');
        }
        else if(member.name == master) {
            masterOptime = member.optime.ts.getTime();
            masterOptimeDate = member.optimeDate.getDate();
        }
    }
    if(myOptime && myOptimeDate) {
        var optimeDiff = myOptime - masterOptime ;
        var optimeDateDiff = myOptimeDate - masterOptimeDate ;
        print('optime diff: ' + optimeDiff);
        print('optimeDate diff: ' + optimeDateDiff);
    }
else {
    print(me + ' is not secondary');
}
}
EOF

CHK=`cat $TFile1 |grep -i 'Failed to connect' `
if [[ ! -z $CHK  ]] ; then
    /bin/mailx -s "$HOSTNAME::Mongodb::Can not connect to local instance" $LEVEL_ALERT < $TFile1
fi

CHK=`cat $TFile1 | grep -i 'not reachable' ` 
if [[ ! -z $CHK  ]] ; then 
    /bin/mailx -s "$HOSTNAME::Mongodb::Rep_mon::Not Reachable" $LEVEL_ALERT < $TFile1
fi

if [[ -s $TFile1 ]] ; then
  delay_sec=`cat $TFile1 |grep -i 'optime diff' |cut -d ' ' -f3`
  DELAY=`echo $delay_sec/300 |bc `   ## 300 seconds
  if [[ $DELAY >0 ]] ; then
      /bin/mailx -s "$HOSTNAME::Mongodb::Rep_mon::Replication Latency Warning" $LEVEL_ALERT < $TFile1 
  fi 
fi


## purge log file 
find  ~/admin/log/* -mtime +30 -exec rm {} \; 
