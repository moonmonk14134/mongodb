#!/etc/bin/env python3
import sys,time
import subprocess
from pymongo import MongoClient
from bson.son import SON
import pprint


connStr="localhost:27018:mnDb"
(hostname, portNo, database)= connStr.split(":")

connection = MongoClient(host=hostname, port=int(portNo))
db01 = connection[database]  ##  db01 = connection.database:: "." does not work
collection01= "dbstats"
coll01 = db01[collection01]

fname = sys.argv[0]
fname02 = os.path.basename(sys.argv[0])
# test DB connection
#print( db01.command(  "ismaster")) 

## sort example
## coll01.find({'Host' :'mgcf01l-con-08'}).sort(['TS', -1],['Version', -1] ).limit(2)

#print( db01.command( { listDatabases: 1 })) 

##db01.close()
