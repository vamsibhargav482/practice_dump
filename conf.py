from pysnmp.hlapi import *
from pysnmp.smi import ObjectIdentity

# Define SNMP parameters
community_string = 'public'
ip_address = '18.219.51.6'
port = 1611  # or 1612 for the second simulator
base_oid = '.1.3.6.1.4.1.4171.40.'

# Function to fetch SNMP data
def get_snmp_data(oid):
    iterator = getCmd(
        SnmpEngine(),
        CommunityData(community_string),
        UdpTransportTarget((ip_address, port)),
        ContextData(),
        ObjectType(ObjectIdentity(base_oid + oid))
    )
    
    error_indication, error_status, error_index, var_binds = next(iterator)
    
    if error_indication:
        print(error_indication)
        return None
    elif error_status:
        print('%s at %s' % (error_status.prettyPrint(), error_index and var_binds[int(error_index) - 1][0] or '?'))
        return None
    else:
        return var_binds[0][1]

# Fetch and print SNMP data
def main():
    # Fetch SNMP data from counters.conf file
    try:
        with open('counters.conf', 'r') as file:
            for line in file:
                line = line.strip()
                if line:
                    values = line.split()
                    if len(values) == 2:
                        interface_id, capacity = values
                        oid = interface_id.replace('.', '')  # Remove dots from interface ID
                        data = get_snmp_data(oid)
                        if data is not None:
                            print(f"Interface ID: {interface_id}, Capacity: {capacity}, Value: {data}")
                    else:
                        print(f"Invalid line: {line}")
    except FileNotFoundError:
        print("counters.conf file not found.")

if __name__ == '__main__':
    main()