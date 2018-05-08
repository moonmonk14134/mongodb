#!/etc/bin/env python3

import importlib.machinery
import sys,time,os
import subprocess
import pprint

mongoDbStats= importlib.machinery.SourceFileLoader('modulename','/home/mongod/scripts/mongoDbStats.py').load_module()
hostList=['mgcf01l-con-08:27019','mgcl01l-con-08:27017','mgcl02l-con-08:27017','mgcl04l-con-08:27017','mgcl05l-con-08:27017']
mconn = 'mgcf01l-con-08:27018:mnDb'
##mconn = 'localhost:27018:mnDb'

hname = subprocess.getstatusoutput('hostname -a')[1]
rptloc = '/home/mongod/monitor/rpt/'+hname+'/'
Today = time.strftime('%Y%m%d')
fname = os.path.basename(sys.argv[0])
Ofname = rptloc + fname + '.' +Today+ '.out'
sys.stdout = open(Ofname,'a')


print("\n\n"+"="*63,"\n"+"="*63)
print("="*2 +" "+ " "+ time.strftime("%Y_%m_%d %H:%M") +" "+"="*2)
print("="*63)
for connStr in hostList :
  prStat = mongoDbStats.MongoStat(connStr, mconn)
