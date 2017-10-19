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

mongo --ssl --sslAllowInvalidCertificates --host $HOST:$PORT  --sslPEMKeyFile=/etc/ssl/$MONGOPEM --sslCAFile=/etc/ssl/$ROOTPEM  -u $USER -p $PW  --authenticationDatabase $DB  << EOF
use admin
db.runCommand( { logRotate : 1 } )

EOF
