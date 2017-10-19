import boto3
import datetime

def lambda_handler(event, context):

  expired_date = datetime.datetime.now().strftime("%Y%m%d")
  ec2 = boto3.client('ec2', region_name='us-east-1')

  filters01 = [
    {'Name': 'tag-key', 'Values': ['Expiration']},
    {'Name': 'tag-value', 'Values': [expired_date]},
  ]
  snapshot_response = {}

  snapshot_response = ec2.describe_snapshots(Filters=filters01)
  snapid_list= []
  for kk in snapshot_response['Snapshots']:
    rec_SnapshotId = kk['SnapshotId']
    snapid_list.append(rec_SnapshotId)

  del_snap_no = len(snapid_list)
  print (" There are {} snapshots expired. ".format(del_snap_no) )
   
  for snapID in snapid_list:
    print ("ec2.delete_snapshot(SnapshotId = ['{}'])".format(snapID) ) 
    ec2.delete_snapshot(SnapshotId = snapID)

  return None
        
   