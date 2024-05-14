#!/usr/bin/env python3

from pysnmp.hlapi import *
import sys
from pysnmp.hlapi import *
import time

# Command line arguments are stored in agnt_inp
agnt_inp = sys.argv
# RequestInterval is calculated as the inverse of the second command line argument
RequestInterval = 1 / float(agnt_inp[2])
# The first command line argument is split into ip, port, and commun
ip, port, commun = agnt_inp[1].split(':')
# The third command line argument is converted to an integer and stored in ReqSamp
ReqSamp = int(sys.argv[3])

# Initialize empty list for ObjIDs
ObjIDs = []
for x in range(4, len(agnt_inp)):
    ObjIDs.append(sys.argv[x])
ObjIDs.insert(0, '1.3.6.1.2.1.1.3.0')

# Initialize an empty string for time_laststamp
time_laststamp = ""
# Initialize dt1_NextTime as 0
dt1_NextTime = 0

# Function to get response from SNMP agent
def getResp():
    errorIndication, errorStatus, errorIndex, varBinds = next(
        getCmd(SnmpEngine(),
               CommunityData(commun),
               UdpTransportTarget((ip, int(port))),
               ContextData(),
               *[ObjectType(ObjectIdentity(oid)) for oid in ObjIDs]
               )
    )

    if errorIndication:
        print(errorIndication)
    elif errorStatus:
        print('%s at %s' % (errorStatus.prettyPrint(),
                            errorIndex and varBinds[int(errorIndex) - 1][0] or '?'))
    else:
        return varBinds

# Function to process the response from the SNMP agent
def getResp_process(resp):
    global time_laststamp, dt1_NextTime

    nxtOID = []
    dt2_NextTime = time.time()

    for varBind in resp:
        (_, val) = varBind
        nxtOID.append(int(val))

    # Similar logic for rate calculation and printing as in the original script

    dt1_NextTime = dt2_NextTime

# Function to run the probe continuously
def run_probe():
    s = 0

    while True:
        dt2_NextTime = time.time()
        resp = getResp()
        getResp_process(resp)

        if s != 0:
            print(end="\n")

        timenow = time.time()
        s += 1
        time.sleep(abs(RequestInterval - timenow + dt2_NextTime))

# Function to run the probe for a specific number of samples
def run_sample():
    for s in range(0, ReqSamp + 1):
        dt2_NextTime = time.time()
        resp = getResp()
        getResp_process(resp)

        if s != 0:
            print(end="\n")

        timenow = time.time()
        time.sleep(abs(RequestInterval - timenow + dt2_NextTime))

if ReqSamp == -1:
    run_probe()
else:
    run_sample()
