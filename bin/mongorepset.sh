#!/bin/bash
###########################
# Environment
###########################
#LEVEL_ALERT=dbops@webmd.net
#LEVEL_ERROR=dbops@webmd.net
#LEVEL_CRITICAL=dbops@webmd.net
#LEVEL_CRITICAL=dbaops-poc@iad1.webmd.com
. ~/.bashrc
#############################################
#### Log Files and MAIL_TEXT files:
#############################################
LOG_FILE=/tmp/mongorepset.log;
MAIL_TEXT=/tmp/mongorepset.txt;
LOG_FILE_FULL=/tmp/mongorepset_full.log;
: > $LOG_FILE_FULL;
: > $LOG_FILE;
: > $MAIL_TEXT;
#############################################
#-------------- FIND HOST NAME
old_IFS=$IFS;
START_TIME=`date +"%m/%d/%Y %k:%M:%S"`;
#-------------- FIND HOST NAME
HOSTNAME=`uname -n`;
PORT_S=27018;
#-------------- FIND SHARDS AND REPLICA SETS
IFS=$'\n';
j=0;
for SHARD_SERVER in `mongo --quiet --nodb << ! | gawk -F" " '$1 ~ /^"/{print $1"|"$2}' | sed '{ :start; s/"//; t start }'; 
#conn = new Mongo("moncf21q-prf-08.portal.webmd.com:27018");
conn = new Mongo("${HOSTNAME}:${PORT_S}");
db = conn.getDB("admin");
var s = db.runCommand({ listshards: 1 });
//printjson(s);
//printjson(s.shards);
//s.shards.forEach(function(x) { printjson(x.host)});
	for ( var i=0; i<s.shards.length; i++ ){ printjson(s.shards[i]._id + " " + s.shards[i].host)}; 
!`; do
			   SHARD_NAME=`echo ${SHARD_SERVER} | cut -d "|" -f1 -`; 
		SHARD_SERVER_LIST=`echo ${SHARD_SERVER} | cut -d "|" -f2 - | cut -d "/" -f2 -`; 
		SHARD_SERVER_LIST_ARR[$j]=${SHARD_SERVER_LIST};
		(( j ++ ));
done;
#-------------- CHECKING REPLICA SETS  
PORT_D=27017;
IFS=$old_IFS;		
for SERVER_NAME_LIST in ${SHARD_SERVER_LIST_ARR[@]}; do  
: > $LOG_FILE;
	IFS=$old_IFS;
	for SERVER_NAME in `echo ${SERVER_NAME_LIST} | sed '{ :start; s/,/ /; t start }'`; do   		
		PRIMARY_EXIST=0;
		ERROR_EXIST=0;
	    CHECK_NEW_REPLICA_HOST=0;
	    k=0;
	    IFS=$'\n';		
		for REP_SERVER in `mongo --quiet --nodb --norc << ! | gawk -F " " '$0 ~ /^"| Error:/{print $0}' | sed '{ :start; s/"//; t start }';
		#conn = new Mongo("moncl21q-prf-08.portal.webmd.com:27017");
		conn = new Mongo("${SERVER_NAME}");
		db = conn.getDB("admin");
		var rs = db.runCommand({ replSetGetStatus: 1 });
			// for ( var i=0; i<rs.members.length; i++ ){ printjson(rs.members[i].stateStr + " " + rs.members[i].name)};
			   for ( var i=0; i<rs.members.length; i++ ){ printjson(rs.members[i].state + "|" + rs.members[i].name + "|" + rs.members[i].stateStr + "|" + rs.members[i].errmsg + "|" + rs.members[i].pingMs)};
		!`; do
				if [[ ${REP_SERVER} =~ "^.*Error:.*$" ]]; then 
						echo "Connection to the host: ${SERVER_NAME} failed:" >> ${LOG_FILE};
						echo "${REP_SERVER}" >> ${LOG_FILE};
					CHECK_NEW_REPLICA_HOST=1;	
					break; # Skipping to the next replica host of the same shard. 
				fi;								
				REP_SERVER_ARR[$k]=${REP_SERVER};
				REP_SERVER_STATE=`echo ${REP_SERVER} | cut -d "|" -f1 -`; 
				REP_SERVER_NAME=`echo ${REP_SERVER} | cut -d "|" -f2 -`; 
				REP_SERVER_STATESTR=`echo ${REP_SERVER} | cut -d "|" -f3 -`; 
				REP_SERVER_ERRMSG=`echo ${REP_SERVER} | cut -d "|" -f4 -`; 
				REP_SERVER_PINGMS=`echo ${REP_SERVER} | cut -d "|" -f5 -`; 		
			
				{
				echo "---------------------------------------------------------------------" ;
				case ${REP_SERVER_STATE} in
				0)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : STARTUP (Start up, phase 1 (parsing configuration.))" ;;	
				1)
				    PRIMARY_EXIST=1;
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : PRIMARY" ;;
				2)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : SECONDARY" ;;	
				3)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : RECOVERING (Member is recovering: initial sync, post-rollback, stale members.)" ;;
				4)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : FATAL (Member has encountered an unrecoverable error.)" ;;
				5)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : STARTUP2 	(Start up, phase 2 (forking threads.))" ;;
				6)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : UNKNOWN (The set has never connected to the member.)" ;;
				7)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : ARBITER (Member is an arbiter.)" ;;
				8)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : DOWN (Member is not accessible to the set.)" ;;	
				9)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ROLE : ROLLBACK 	Member is rolling back data." ;;			
				*)
					echo "SERVER NAME: ${REP_SERVER_NAME}" ; 
					echo "ERROR: NOT Defined State!";;
				esac;  
				if [ $(echo "${REP_SERVER_ERRMSG}" | tr [:upper:] [:lower:]) != "undefined" ] ; then 
				ERROR_EXIST=1;
				echo "ERRMSG : ${REP_SERVER_ERRMSG}"; 
				fi;	
				echo "---------------------------------------------------------------------" ;
				} >> ${LOG_FILE} 2>&1;
				(( k ++ ));
			done;			
		if [ ${CHECK_NEW_REPLICA_HOST} -eq 0 ]; then
            cat ${LOG_FILE} >> ${LOG_FILE_FULL} 2>&1;  		
			break; # Do Not iterate any more (Connection was successful).
		fi;	
		echo "---------------------------------------------------------------------" >> ${LOG_FILE_FULL};
		cat ${LOG_FILE} >> ${LOG_FILE_FULL} 2>&1;  
		echo "---------------------------------------------------------------------" >> ${LOG_FILE_FULL}; 
	done;
	IFS=$old_IFS;
	###########################################################
	####### Sending Warning/Error E-Mail for each shard ####### 
	###########################################################
	#--------- If There is No Primary Replica set 
	if [[ ${PRIMARY_EXIST} -eq 0 ]]; then
		echo "MongoDB Primary Replica set Not found on the shard." > ${MAIL_TEXT} ;
		cat ${LOG_FILE} >> ${MAIL_TEXT} 2>&1; 		
		/bin/mailx -s "MongoDB Primary Replica set not found." $LEVEL_CRITICAL < ${MAIL_TEXT};
	fi;
	#--------- If There is any Error Messages (Not caused by Non_existing Primary Replica set )
	if [[ ${PRIMARY_EXIST} -ne 0 ]] && [[ ${ERROR_EXIST} -ne 0 ]]; then
		echo "Warning or Error message found on the following hosts of the same shard:" > ${MAIL_TEXT} ;
		cat ${LOG_FILE} >> ${MAIL_TEXT} 2>&1; 
		/bin/mailx -s "Warning or Error message found." $LEVEL_ERROR < ${MAIL_TEXT};
	fi;	
	#-------------------------------------------------
done; 

