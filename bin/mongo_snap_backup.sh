#############################################################################
##  mongo_snap_backup.sh
##         Purpose : take snapshots on config server and sharding db servers.
##         Syntax: 
##                   mongo_snap_backup.sh cluster_name bk_vol.lst  
##                   EX.
##                      $> mongo_snap_backup.sh MongoDB-nonprod-ICP-401q /home/mongod/admin/bin/bk_vol.lst
##         Date:     2017/08/07
##         Version:  1.0.1
##         
##         Date:     2017/08/16
##         Version:  1.0.2
##                   Rename: mongo_snap_backup.sh
##                   remove S3 option
##         Date      2017/09/18
##                   Add the session of Retrieve mongodb connection info      
##                   Add functions
##############################################################################
#!/bin/sh
#set -x

if [[ -z $1  ]] ; then
    echo backup_sh_snap.sh cluster_name  bk_vol.lst
    exit 1
fi

. /home/mongod/aws_env 
Cluster=$1 
VList=${2:-/home/mongod/admin/bin/bk_vol.lst}

. ~/.bashrc
Date=`date '+%Y%m%d_%H%M%S'`
ExpireDate=`date -d "+30 days" '+%Y%m%d' ` 
LOG=/home/mongod/admin/log/${0##*/}.$Date.out
exec >$LOG 2>&1
TFILE=/tmp/tmp1
cat /dev/null >$TFILE
touch $TFILE 

## Retrieve mongodb connection info
passwdfile=/home/mongod/control/.passwd
### ServerType=${1-mongod}  
ServerType=mongod
INFO=`grep $ServerType $passwdfile`
var=( $(echo $INFO |cut -d: --output-delimiter=' ' -f2-8 ) )
HOST=${var[0]}
PORT=${var[1]}
MONGOPEM=${var[2]}
ROOTPEM=${var[3]}
USER=${var[4]}
PW=${var[5]}
DB=${var[6]}



## FUNCTION ##
Chk_Bal()  ## Check Balancer Status 
{
## Check Balancer Status
## No need to stop/start mongodb balancer ; Balancer window : 1am~23:59pm
echo =========================== >>$LOG 
echo Check Balancer Status       >>$LOG
echo =========================== >>$LOG
echo >>$LOG

mongo --ssl --sslAllowInvalidCertificates --host $HOST --port=$PORT  --sslPEMKeyFile=/etc/ssl/$MONGOPEM --sslCAFile=/etc/ssl/$ROOTPEM  -u $USER -p $PW  --authenticationDatabase $DB  << EOF >> $LOG
use config ;
sh.status();
EOF

####  sh.stopBalancer(timeout, interval)  , in case you need to stop Balancer manually .
}


SNAP_BK()  ## Snapshot backup on config server and sharding DB servers
{

## Backup config server
DBSerLst=`grep 'config' $VList |cut -d" " -f2- ` 
echo ======================================== >>$LOG 
echo Start Snapshot backup at `date`          >>$LOG
echo ======================================== >>$LOG
echo >>$LOG

for Vol in $DBSerLst ; do
   echo ec2-create-snapshot -d "bk snap ${Cluster} ${Date} ${Vol}"  $Vol >>$LOG 
   ec2-create-snapshot -d "bk snap $Cluster $Date $Vol"  $Vol >>$LOG 
   sleep 5
   SNAP_ID=`ec2-describe-snapshots --filter "description=bk snap ${Cluster} ${Date} ${Vol}" |cut -d$'\t' -f2  ` 
   echo '## SNAP_ID: '  $SNAP_ID >> $LOG
   SNAP_NAME=BkSnap${Cluster}${Date}${Vol}
   echo '## SNAP_NAME: '  $SNAP_NAME >> $LOG
   echo aws ec2 create-tags --resources $SNAP_ID --tags Key=Name,Value=$SNAP_NAME Key=Cluster,Value=$Cluster Key=Expiration,Value=$ExpireDate >> $LOG
   aws ec2 create-tags --resources $SNAP_ID --tags Key=Name,Value=$SNAP_NAME Key=Cluster,Value=$Cluster Key=Expiration,Value=$ExpireDate 
done
  
## backup sharding DB servers
DBSerLst=`grep 'db' $VList |cut -d" " -f2- `  
for Vol in $DBSerLst ; do
   echo ec2-create-snapshot -d "bk snap ${Cluster} ${Date} ${Vol}"  $Vol >>$LOG
   ec2-create-snapshot -d "bk snap $Cluster $Date $Vol"  $Vol  >>$LOG
   sleep 5
   SNAP_ID=`ec2-describe-snapshots --filter "description=bk snap ${Cluster} ${Date} ${Vol}" |cut -d$'\t' -f2 ` 
   echo  SNAP_ID: $SNAP_ID >> $LOG 
   SNAP_NAME=BkSnap${Cluster}${Date}${Vol}
   aws ec2 create-tags --resources $SNAP_ID --tags Key=Name,Value=$SNAP_NAME Key=Cluster,Value=$Cluster Key=Expiration,Value=$ExpireDate 
done

echo ================================================================================= >> $LOG
echo ec2-describe-snapshots --O $AAK --W $ASK --filter "description=bk snap ${Cluster} ${Date} ${Vol}" >> $LOG
echo ================================================================================= >> $LOG
echo >>$LOG
#### ec2-describe-snapshots --O $AAK --W $ASK --filter "description=bk snap ${Cluster} ${Date}*" |tee $TFILE  
echo 'Describe Snapshot:  ' ec2-describe-snapshots --filter "description=bk snap ${Cluster} ${Date}*" |tee $TFILE  
ec2-describe-snapshots --filter "description=bk snap ${Cluster} ${Date}*" |tee $TFILE  
SStatus=`grep pending $TFILE` 
echo $SStatus >> $LOG

while [[ ! -z $SStatus ]] ; do
  echo ........... `/bin/date` >> $LOG
  sleep 1m
  cat /dev/null > $TFILE
  #### ec2-describe-snapshots --O $AAK --W $ASK --filter "description=bk snap ${Cluster} ${Date}*" |grep pending |tee $TFILE
  ec2-describe-snapshots --filter "description=bk snap ${Cluster} ${Date}*" |grep pending |tee $TFILE
  SStatus=`grep pending $TFILE` 
done      
  
}


## Main ##
 
  echo Snapshot backup start at `date`  >> $LOG
  Chk_Bal
  SNAP_BK
  Chk_Bal
#### rm -rf $TFILE
  echo Snapshot backup ends at `date`  >> $LOG

