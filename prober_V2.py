#!/usr/bin/python3

import sys,time
import easysnmp
import math
from easysnmp import Session
from easysnmp import snmp_get,snmp_walk

#first get all the data from command line

#getting agent details
agent=sys.argv[1]
input=agent.split(':')
agent_IP=input[0]
agent_PortNo=input[1]
agent_Community=input[2]

sample_freq=float(sys.argv[2])
no_sample=int(sys.argv[3])

sample_time=(1/(sample_freq)) #use to finding sample time
#print(sample_time)

#arrays to store oid for calculating rate
oid=[]
starting_oid=[]
next_oid=[]

#loop to count number of oids entered and to store them
for no_oid in range(4,len(sys.argv)):
	oid.append(sys.argv[no_oid])
oid.insert(0,'1.3.6.1.2.1.1.3.0')

#creating an SNMP session to be used for all our request
session=Session(hostname=agent_IP,remote_port=agent_PortNo,community=agent_Community,version=2)	
	
def snmp_prober(): #defining function to be called and runned for finding rate of change of OIDs
	global starting_oid, starting_time,reply
	reply=session.get(oid) #retriveing an individual oid using an SNMP get
	next_oid=[]
	for r in range(1,len(reply)):
		if reply[r].value!='NOSUCHOBJECT' and reply[r].value!='NOSUCHINSTANCE':
			next_oid.append(int(reply[r].value))
			
			if c!=0 and len(starting_oid)>0:
				numerator=int(next_oid[r-1]) - int(starting_oid[r-1])
				denominator=(next_time-starting_time)
				bps = int(numerator / denominator)
				
				if bps < 0 : #wrapping of counters problem rectification
					if response[get_oids].snmp_type == 'COUNTER32': 
						numerator = numerator + 2**32
						print(str(next_time) +"|"+ str(numerator / denominator) +"|")
					elif response[get_oids].snmp_type == 'COUNTER64':
						numerator = numerator + 2**64
						print(str(next_time) +"|"+ str(numerator / denominator) +"|")
				else:
					print(str(next_time) +"|"+ str(numerator / denominator) +"|")

	starting_oid=next_oid
	starting_time=next_time
	#above logic assigns current value as previous value and probes another value for current


if no_sample!=-1: 
	first_oid=[]
	for c in range(0,no_sample+1):
		next_time=float(time.time())
		snmp_prober()
		reply_time=float(time.time()) 
		ms=(reply_time)-(next_time)
		#print(ms)
		if sample_time<ms: #code to sleep before collecting next probe
			x=math.ceil(ms/sample_time)
			#y=round(sample_time,2)
			z=((x*(sample_time))-ms)
			#print(y)
			time.sleep(z)
		else:
			time.sleep((sample_time)-ms)
else:			#code for number of samples =-1, to run continuously
	c=0
	first_oid=[]
	while True:
		next_time=float(time.time())#returns time as a floating point in secs
		snmp_prober()
		reply_time=float(time.time())
		c+=1
		ms=(reply_time)-(next_time)
		#print(ms)
		if sample_time<ms: #code to sleep before collecting next probe
			n=math.ceil(ms/sample_time)
			time.sleep((n*(sample_time))-ms)
		else:
			time.sleep((sample_time-ms))
