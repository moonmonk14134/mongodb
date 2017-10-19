#!/bin/bash
###########################
# Version 1.1
# Environment
###########################

LEVEL_ALERT=dbops@webmd.net
LEVEL_CRITICAL=dbops@webmd.pagerduty.com

THRESHOLD_CRITICAL=0.1  ## 0.1
THRESHOLD_ALERT=0.2     ## 0.2
#############################################
#### Log Files and MAIL_TEXT files:
#############################################
LOG_FILE=/tmp/mongo_space_check.log
MAIL_TEXT=/tmp/mongo_space_check.txt
cat /dev/null > $LOG_FILE
cat /dev/null > $MAIL_TEXT
#### old_IFS=$IFS
START_TIME=`date +"%m/%d/%Y %k:%M:%S"`

THRESHOLD_CRITICAL_PCT=$(echo ${THRESHOLD_CRITICAL}*100 | bc -l) 
THRESHOLD_ALERT_PCT=$(echo ${THRESHOLD_ALERT}*100 | bc -l) 

if [[ -z $POSIXLY_CORRECT ]] ; then   
	#echo "POSIXLY_CORRECT is Not Defined"
	BLOCKS=1024
else
	#echo "POSIXLY_CORRECT is Defined"
	BLOCKS=512
fi

HOSTNAME=$(uname -n)
MONGODB=$(ps -ef | grep -i '/usr/bin/mongod' | grep -v grep)
if [ $? -ne 0 ]; then
	echo "HOST : ${HOSTNAME}" > ${MAIL_TEXT} 
	echo "Mongo DB (mongod) is not running ...." >> ${MAIL_TEXT}  
	/bin/mailx -s "mongod is not running on ${HOSTNAME}" $LEVEL_CRITICAL < ${MAIL_TEXT}
	/bin/mailx -s "mongod is not running on ${HOSTNAME}" $LEVEL_ALERT < ${MAIL_TEXT}
	cat ${MAIL_TEXT} > ${LOG_FILE}
else {
	MONGOD_CONF=$(ps -ef | grep -i 'mongod.conf' | grep -v grep | awk '{print $NF}') 
	MONGOD_DBPATH=$(cat ${MONGOD_CONF} | grep 'dbPath' | awk -F': ' '{print $NF}')
	MONGOD_DISK_USAGE=$(du -s ${MONGOD_DBPATH} | awk '{print $1}')
	
	DF_RESULT=$(df ${MONGOD_DBPATH} | grep '[0-9]%') 
	NF_RESULT=$(echo ${DF_RESULT} | awk '{print NF}') 
	
	case ${NF_RESULT} in	
	5)
	    TOTAL_SPACE=$(df ${MONGOD_DBPATH} | grep '[0-9]%' | awk '{print $1}'); 
	    TOTAL_SPACE_USED=$(df ${MONGOD_DBPATH} | grep '[0-9]%' | awk '{print $2}')     
	    TOTAL_SPACE_FREE=$(df ${MONGOD_DBPATH} | grep '[0-9]%' | awk '{print $3}') 	
 	   ;;     	
	6) 
	    TOTAL_SPACE=$(df ${MONGOD_DBPATH} | grep '[0-9]%' | awk '{print $2}'); 
            TOTAL_SPACE_USED=$(df ${MONGOD_DBPATH} | grep '[0-9]%' | awk '{print $3}')     
	    TOTAL_SPACE_FREE=$(df ${MONGOD_DBPATH} | grep '[0-9]%' | awk '{print $4}') 
	   ;;
	esac 
	
		FREE_PCT=$(echo ${TOTAL_SPACE_FREE}/${TOTAL_SPACE} | bc -l)  
		USED_PCT=$(echo ${TOTAL_SPACE_USED}/${TOTAL_SPACE} | bc -l)  	
	
	if (( $(echo ${FREE_PCT} \< ${THRESHOLD_CRITICAL} | bc -l) ));  then 
		echo "Mongo DB free disk space is less then ${THRESHOLD_CRITICAL_PCT}%" > ${MAIL_TEXT} 	
		echo "HOST : ${HOSTNAME}" >> ${MAIL_TEXT} 
		echo "Mongo DB Path: ${MONGOD_DBPATH}" >> ${MAIL_TEXT} 		
		echo "------------------------------------------" >> ${MAIL_TEXT} 
		echo "Available (Free) Space: $[${TOTAL_SPACE_FREE}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "Used Space: $[${TOTAL_SPACE_USED}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "Total Space: $[${TOTAL_SPACE}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "Mongo DB disk usage: $[${MONGOD_DISK_USAGE}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "------------------------------------------" >> ${MAIL_TEXT} 
				
		/bin/mailx -s "Mongo DB free disk space is less then ${THRESHOLD_CRITICAL_PCT}% on ${HOSTNAME}" $LEVEL_CRITICAL < ${MAIL_TEXT}		
		/bin/mailx -s "Mongo DB free disk space is less then ${THRESHOLD_CRITICAL_PCT}% on ${HOSTNAME}" $LEVEL_ALERT < ${MAIL_TEXT}
		
		cat ${MAIL_TEXT} > ${LOG_FILE}
		
	elif (( $(echo ${FREE_PCT} \< ${THRESHOLD_ALERT} | bc -l) ));  then 
		echo "Mongo DB free disk space is less then ${THRESHOLD_ALERT_PCT}%" > ${MAIL_TEXT} 	
		echo "HOST : ${HOSTNAME}" >> ${MAIL_TEXT} 
		echo "Mongo DB Path: ${MONGOD_DBPATH}" >> ${MAIL_TEXT} 
		echo "------------------------------------------" >> ${MAIL_TEXT} 
		echo "Available (Free) Space: $[${TOTAL_SPACE_FREE}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "Used Space: $[${TOTAL_SPACE_USED}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "Total Space: $[${TOTAL_SPACE}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
		echo "Mongo DB disk usage: $[${MONGOD_DISK_USAGE}/${BLOCKS}] MB" >> ${MAIL_TEXT} 
        echo "------------------------------------------" >> ${MAIL_TEXT} 		
		
		/bin/mailx -s "Mongo DB free disk space is less then ${THRESHOLD_ALERT_PCT}% on ${HOSTNAME}" $LEVEL_ALERT < ${MAIL_TEXT}	
		
		cat ${MAIL_TEXT} > ${LOG_FILE} 
		
	else	
		echo "Mongo DB free disk space is more then ${THRESHOLD_ALERT_PCT}%" > ${LOG_FILE} 	
		echo "HOST : ${HOSTNAME}" >> ${LOG_FILE} 
		echo "Mongo DB Path: ${MONGOD_DBPATH}" >> ${LOG_FILE} 
		echo "------------------------------------------" >> ${LOG_FILE} 
		echo "Available (Free) Space: $[${TOTAL_SPACE_FREE}/${BLOCKS}] MB" >> ${LOG_FILE} 
		echo "Used Space: $[${TOTAL_SPACE_USED}/${BLOCKS}] MB" >> ${LOG_FILE} 
		echo "Total Space: $[${TOTAL_SPACE}/${BLOCKS}] MB" >> ${LOG_FILE} 
		echo "Mongo DB disk usage: $[${MONGOD_DISK_USAGE}/${BLOCKS}] MB" >> ${LOG_FILE} 
        echo "------------------------------------------" >> ${LOG_FILE} 											
	fi 	
	}
fi	
	
exit
  
