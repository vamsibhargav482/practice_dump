#!/usr/bin/env python3

import time
import easysnmp
import sys
from collections import defaultdict

def prober(agent, sample_frequency, samples, *oids):
    session = easysnmp.Session(hostname=agent[0], remote_port=int(agent[1]), community=agent[2], version=2)
    counter_values = defaultdict(list)
    counter_times = defaultdict(list)
    sample_count = 0

    # Initialize prev_values with the first sample values
    try:
        for oid in oids:
            result = session.get(oid)
            counter_values[oid].append(int(result.value))
            counter_times[oid].append(int(session.get('1.3.6.1.2.1.1.3.0').value))
    except easysnmp.EasySNMPTimeoutError:
        print('Timeout error, the device did not respond in time.')
    except easysnmp.EasySNMPError as error:
        print(f'Error: {error}')

    while sample_count < samples or samples == -1:
        start_time = time.time()
        try:
            sysUpTime = session.get('1.3.6.1.2.1.1.3.0').value
            for oid in oids:
                result = session.get(oid)
                counter_values[oid].append(int(result.value))
                counter_times[oid].append(int(sysUpTime))

                if len(counter_values[oid]) > 1:
                    rate = (counter_values[oid][-1] - counter_values[oid][-2]) / (counter_times[oid][-1] - counter_times[oid][-2])
                    print(f'{counter_times[oid][-1]} | {rate}')
            sample_count += 1
        except easysnmp.EasySNMPTimeoutError:
            print('Timeout error, the device did not respond in time.')
        except easysnmp.EasySNMPError as error:
            print(f'Error: {error}')
        end_time = time.time()
        elapsed_time = end_time - start_time
        sleep_time = max(1/sample_frequency - elapsed_time, 0)
        time.sleep(sleep_time)

if __name__ == "__main__":
    agent = sys.argv[1].split(':')
    sample_frequency = float(sys.argv[2])
    samples = int(sys.argv[3])
    oids = sys.argv[4:]
    for oid in oids:
        prober(agent, sample_frequency, samples, oid)
