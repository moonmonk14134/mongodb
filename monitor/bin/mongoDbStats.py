#!/etc/bin/env python3

import os, sys,random
import time
from datetime import datetime
from pymongo import MongoClient
from optparse import OptionParser
import subprocess
import signal
from urllib.parse import urlparse
import json
from bson.son import SON
import pprint

class MongoStat:
    def __init__(self, conStr='localhost:27019', mons='localhost:27018:mnDb'):

        (hostname,portNo) = conStr.split(":")
        ## connection = MongoClient(host=hostname, port=int(portNo))
        connection = MongoClient(host=hostname, port=int(portNo), document_class=SON)
        self.db = connection['admin']

        (mhostname,mportNo,mDb) = mons.split(":")
        ## mconn = MongoClient(host=mhostname, port=int(mportNo))
        mconn = MongoClient(host=mhostname, port=int(mportNo), document_class=SON)
        self.mdb = mconn[mDb]

        ##print( self.db.command('ismaster') )
        self.printDbStats()
        self.inserDBStats()
        self.genDBStatsDelRpt()     ## comment this line when you run this script at the first time
        connection.close()
        mconn.close()


    def inserDBStats(self):
        collection01 = self.mdb.dbstats
        host = self.matr01["Host"]
        collection01_id = collection01.insert_one(self.matr01).inserted_id
        pprint.pprint(collection01_id)

    def genDBStatsDelRpt(self):
        collection01 = self.mdb.dbstats
        collection02 = self.mdb.DBStatsDelRpt
        host = self.matr01["Host"]
        version = self.matr01["Version"]
        result01 = collection01.find({'Host': host}).sort('TS', -1).limit(2)
        rec01 = []
        for c in result01 :
          rec01.append(c)

        DStats = {}
        DCurrConn = int(rec01[0]['CurrConn']) - int(rec01[1]['CurrConn'])
        DNofWarning = int(rec01[0]['NofWarning']) - int(rec01[1]['NofWarning'])
        DNofUserMessage = int(rec01[0]['NofUserMessage']) - int(rec01[1]['NofUserMessage'])
        DMaxMem = int(rec01[0]['MaxMem']) - int(rec01[1]['MaxMem'])
        DCurrMem = int(rec01[0]['CurrMem']) - int(rec01[1]['CurrMem'])
        DInsert = int(rec01[0]['Insert']) - int(rec01[1]['Insert'])
        DQuery = int(rec01[0]['Query']) - int(rec01[1]['Query'])
        DUpdate = int(rec01[0]['Update']) - int(rec01[1]['Update'])
        DDelete = int(rec01[0]['Delete']) - int(rec01[1]['Delete'])
        DGetmore = int(rec01[0]['Getmore']) - int(rec01[1]['Getmore'])
        DCommand = int(rec01[0]['Command']) - int(rec01[1]['Command'])
        DScanAndOrder = int(rec01[0]['ScanAndOrder']) - int(rec01[1]['ScanAndOrder'])
        DWriteConflicts = int(rec01[0]['WriteConflicts']) - int(rec01[1]['WriteConflicts'])
        DCursorTimedOut = int(rec01[0]['CursorTimedOut']) - int(rec01[1]['CursorTimedOut'])

        DMatr = { 'TS': int(self.thetime()) ,'Host': host, 'Version': version,
          'CurrConn': DCurrConn, 'NofWarning': DNofWarning, 'NofUserMessage': DNofUserMessage,
          'MaxMem': DMaxMem, 'CurrMem': DCurrMem,
          'Insert': DInsert, 'Query': DQuery, 'Update': DUpdate,
          'Delete': DDelete, 'Getmore': DGetmore, 'Command': DCommand,
          'ScanAndOrder': DScanAndOrder, 'WriteConflicts': DWriteConflicts, 'CursorTimedOut': DCursorTimedOut }
      
        collection02_id = collection02.insert_one(DMatr).inserted_id

        pipeline = [
        { "$sort": SON([("Host", 1), ("TS", -1)]) },
        { "$group": { "_id": "$Host", "stats": { "$first": '$$ROOT'} } }
        ]
  
        pprint.pprint(list(collection02.aggregate(pipeline)))



    def thetime(self):
            return time.strftime("%Y%m%d%H%M")

    def thetoday(self):
            return time.strftime("%Y%m%d")

    def hostname(self):
            hostname = subprocess.getstatusoutput('hostname -a')
            return hostname[1][0:]

    def setSignalHandler(self):
        def handler(signal,frame):
            print("GoodBye !\n")
            sys.exit()

        signal.signal(signal.SIGINT, handler)

    def printDbStats(self):
        #data01 = ( self.db.command( { "serverStatus" : 1, "repl": 0, "metrics": 0, "locks": 1, "wiredTiger": 0 } ) )
        data01 = {}
        data01 = ( self.db.command( "serverStatus" )) 
        Host01 = data01["host"][0:14]
        Version01 = data01["version"]
        Connections01 = data01["connections"]["current"]
        Warning = data01["asserts"]["warning"]
        UMess = data01["asserts"]["user"]
        MaxMem = data01["wiredTiger"]["cache"]["maximum bytes configured"]
        CurrMem = data01["wiredTiger"]["cache"]["bytes currently in the cache"]

        Inser = data01["opcounters"]["insert"]
        query = data01["opcounters"]["query"]
        Updat = data01["opcounters"]["update"]
        delet = data01["opcounters"]["delete"]
        getmo = data01["opcounters"]["getmore"]
        comma = data01["opcounters"]["command"]

        Scan = data01["metrics"]["operation"]["scanAndOrder"]
        WConfl = data01["metrics"]["operation"]["writeConflicts"]
        CurTimeout = data01["metrics"]["cursor"]["timedOut"]

        """
        print("\n\n"+"="*20,"\n"+"="*20)
        print("="*2 +" "+ Host01 +" "+ self.thetime() +" "+"="*2)
        print("="*63)
        template01="%15s%8s%10s%15s%15s"
        header01=('Host','Version','Cur_Conn','#ofWarning','#ofUserMessage')
        print( template01 % header01)
        print("="*63)
        print( template01 % (Host01,Version01,Connections01,Warning,UMess))

        template02="%12s%12s%12s%12s%12s%12s%12s%12s"
        header02=('MaxMem MB','CurrMem MB','insert','query','update','delete','getmore','command')
        print( template02 % header02)
        print("="*96)
        print( template02 % (MaxMem,CurrMem,Inser,query,Updat,delet,getmo,comma))

        template03="%15s%15s%15s"
        header03=('scanAndOrder','writeConflicts','CursorTimedOut')
        print( template03 % header03)
        print("="*45)
        print( template03 % (Scan,WConfl,CurTimeout))
        """

        """
        self.matr01={'TS': int(self.thetime()) ,'Host': Host01, 'Version': Version01, 'CurrConn': Connections01, 
          'NofWarning': Warning, 'NofUserMessage': UMess,  
          'MaxMem': MaxMem, 
          'CurrMem': CurrMem, 
          'Insert': Inser, 'Query': query, 'Update': Updat, 
          'Delete': delet, 'Getmore': getmo, 'Command': comma, 
          'ScanAndOrder': Scan, 'WriteConflicts': WConfl, 'CursorTimedOut': CurTimeout }
        """

        self.matr01=SON([('TS', int(self.thetime()) ) ,('Host', Host01), ('Version', Version01), ('CurrConn', Connections01), 
          ('NofWarning', Warning), ('NofUserMessage', UMess),  
          ('MaxMem', MaxMem), 
          ('CurrMem', CurrMem), 
          ('Insert', Inser), ('Query', query), ('Update', Updat), 
          ('Delete', delet), ('Getmore', getmo), ('Command', comma), 
          ('ScanAndOrder', Scan), ('WriteConflicts', WConfl), ('CursorTimedOut', CurTimeout) ])

if __name__ == "__main__":
    MongoStat()

