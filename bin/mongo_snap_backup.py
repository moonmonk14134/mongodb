###############################
## Create 20171011
##
##
################################
#!/usr/bin/env python3

import os.path
import configparser
import logging
import datetime, time
##from datetime import date, timedelta
import boto3

cluster = "MongoDB-nonprod-ICP-401q"
expired_date = (datetime.datetime.now() + datetime.timedelta(-30)).strftime("%Y%m%d")
today = datetime.datetime.now().strftime("%Y%m%d")
curtime = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

##############
## Error LOG
##############
path = os.path.abspath(os.path.join(__file__ ,"../.."))+'/log'
logfile = __file__.split(".")[0]+'.log.'+curtime
lfile = path +"/"+ logfile
print("logfile : " + logfile +'\t'+str(len(logfile)) )
print("path : " + path +'\t'+str(len(path)) )
print("lfile : " + lfile +'\t'+str(len(lfile)) )

with open(lfile, 'w') as logfile:
    pass

logging.basicConfig(filename = lfile , level=logging.INFO,
                    format='%(asctime)s %(levelname)s  %(message)s')

logger=logging.getLogger(__name__)
logger.info('\n Snapshot backup begins at '+str(datetime.datetime.now())+'...')



########################
## chk_file_exist(fname)
########################
def chk_file_exist(fname):
  try:
     with open(fname) as file:
       print (fname + " exists.")
       pass
  except IOError as e:
    print("Unable to open file: "+fname)
    raise 


def mongodb_conf(pfile):
    ##global c
    with open(pfile) as f:
        mline = [ line for line in f if 'mongod' in line ]

    c = {}
    if len( mline[0].split(':')) != 8 :
      try:
           raise Exception()
      except Exception: 
        logger.error("the number of elements in mongo config file is not right.")
        raise

    (c['mclient'],c['host'],c['port'],c['pem'],c['ca'],c['u'],c['pw'],c['admdb']) = mline[0].split(':')

    return c   ## for MONGODB connection in the futhre

#################
## snapshop_bk()
#################
def snapshop_bk():
    path = os.path.abspath(os.path.join(__file__ ,"../.."))  
    config = configparser.RawConfigParser()
    with open(os.path.join(path + '/conf','bk_vol.conf'),'r') as configfile:
        config.readfp(configfile)

    conf_vol_id= config.get('config', 'id')
    db_vol_id= config.get('db', 'id')
    logger.info("conf_vol_id : {}".format(conf_vol_id) ) 
    logger.info("db_vol_id: {}".format(db_vol_id) )

    ## config server EBS backup
    ec2 = boto3.client('ec2')
    for v_id in conf_vol_id.split(":") :
        logger.info("conf_vol_id : {}".format(v_id) )
        logger.info("echo ec2-create-snapshot -d 'bk snap {} {} {}' {} ".format(cluster,today,v_id,v_id) )

        try:
          snap = ec2.create_snapshot(VolumeId = v_id,
                                     Description = 'bk snap '+cluster+' '+curtime+' '+v_id)
        except Exception:
          logger.warning("Check snapshot backup")

        time.sleep(10)
        
        logger.info('SnapshotId: {}'.format(snap['SnapshotId']) )
        mytags = [
                  {"Key": "Cluster", "Value": cluster},
                  {"Key": "Expiration", "Value": expired_date },
                  {"Key": "Name", "Value": 'BkSnap'+cluster+curtime+v_id }
                 ]
        try:
          tag = ec2.create_tags( Resources = [ snap['SnapshotId'] ], Tags = mytags ) 

        except Exception:
          logger.info("Check EC2 tags on Snapshot Backup")

    ## db server EBS backup
    for v_id in  db_vol_id.split(":") :
        logger.info("db_vol_id: {}".format(v_id) )
        logger.info("echo ec2-create-snapshot -d 'bk snap {} {} {}' {} ".format(cluster,today,v_id,v_id) )

        try:
          snap = ec2.create_snapshot(VolumeId = v_id,
                                     Description = 'bk snap '+cluster+' '+curtime+' '+v_id)
        except Exception:
          logger.warning("Check snapshot backup")

        time.sleep(10)

        logger.info('SnapshotId: {}'.format(snap['SnapshotId']) )
        mytags = [
                  {"Key": "Cluster", "Value": cluster},
                  {"Key": "Expiration", "Value": expired_date },
                  {"Key": "Name", "Value": 'BkSnap'+cluster+curtime+v_id }
                 ]
        try:
          tag = ec2.create_tags( Resources = [ snap['SnapshotId'] ], Tags = mytags )

        except Exception:
          logger.info("Check EC2 tags on Snapshot Backup")

    return ('BkSnap'+cluster+curtime)
 

##########################
## backup_valid(s_name)
##########################
def backup_valid(s_name):
    logger.info("==============================================")
    logger.info("===== backup_valid ")
    logger.info("==============================================")
    
    ec2 = boto3.client('ec2')
    tag_val = s_name+'*'
    tag_filter = [
      {'Name': 'tag-key', 'Values': ['Name']},
      {'Name': 'tag-value', 'Values': [tag_val]}
    ]

    ss_status = ec2.describe_snapshots( Filters = tag_filter ) 
    snap_status = []

    checkss = True
    while checkss:
      time.sleep(60)
      for i in ss_status['Snapshots']: 
        snap_status.append(i["State"]) 

      if 'pending' in snap_status:
        checkss = True
        snap_status.insert(0,'snapshot status: ')
        logger.info(snap_status)
        snap_status[:] = []
      else:
        checkss = False
        snap_status.insert(0,'snapshot status: ')
        logger.info(snap_status)
        snap_status[:] = []

    logger.info("==============================================") 
    logger.info("=== Snapshot Backup Completed ================")
    logger.info("==============================================")


###########
## main()
###########
def main():
    tfile = '/home/mongod/control/.passwd'
    ##chk_file_exist(tfile)
    mongo_conn = mongodb_conf(tfile)
    ss_name = snapshop_bk()
    backup_valid(ss_name)
    ## logging.info(c['ca']) 


if __name__ == '__main__':
    main()



