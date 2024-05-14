#!/usr/bin/python3

# Importing necessary modules
import sys, time
import math
from pysnmp.hlapi import *

# Getting agent details from command line
agent = sys.argv[1]
input = agent.split(':')
agent_IP = input[0]
agent_PortNo = int(input[1])
agent_Community = input[2]

# Setting up sampling parameters
sample_freq = float(sys.argv[2])
no_sample = int(sys.argv[3])

sample_time = (1 / sample_freq)  # Calculating sample time

# Arrays to store oid for calculating rate
oid = []
starting_oid = []
next_oid = []

# Loop to count number of oids entered and to store them
for no_oid in range(4, len(sys.argv)):
    oid.append(sys.argv[no_oid])
oid.insert(0, '1.3.6.1.2.1.1.3.0')

# Creating an SNMP session to be used for all our request
session = SnmpEngine()

# Defining function to be called and runned for finding rate of change of OIDs
def snmp_prober():
    global starting_oid, starting_time, reply
    next_oid = []
    for o in oid:
        errorIndication, errorStatus, errorIndex, varBinds = next(
            getCmd(session,
                   CommunityData(agent_Community),
                   UdpTransportTarget((agent_IP, agent_PortNo)),
                   ContextData(),
                   ObjectType(ObjectIdentity(o)))
        )

        if errorIndication:
            print(errorIndication)
        elif errorStatus:
            print('%s at %s' % (errorStatus.prettyPrint(),
                                errorIndex and varBinds[int(errorIndex) - 1][0] or '?'))
        else:
            for varBind in varBinds:
                next_oid.append(int(varBind[1]))

    starting_oid = next_oid
    starting_time = next_time
    # Above logic assigns current value as previous value and probes another value for current

# Collecting samples
if no_sample != -1:
    first_oid = []
    for c in range(0, no_sample + 1):
        next_time = float(time.time())
        snmp_prober()
        reply_time = float(time.time())
        ms = (reply_time) - (next_time)
        if sample_time < ms:  # Code to sleep before collecting next probe
            x = math.ceil(ms / sample_time)
            z = ((x * (sample_time)) - ms)
            time.sleep(z)
        else:
            time.sleep((sample_time) - ms)
else:  # Code for number of samples =-1, to run continuously
    c = 0
    first_oid = []
    while True:
        next_time = float(time.time())  # Returns time as a floating point in secs
        snmp_prober()
        reply_time = float(time.time())
        c += 1
        ms = (reply_time) - (next_time)
        if sample_time < ms:  # Code to sleep before collecting next probe
            n = math.ceil(ms / sample_time)
            time.sleep((n * (sample_time)) - ms)
        else:
            time.sleep((sample_time - ms))
