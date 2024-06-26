#!/bin/bash

##VARIABLES; must be filled correctly
internetNIC1=em1
internetNIC2=br0
##
refdevice1='18.219.51.6'
#refdevice1='192.168.185.60'
#refdevice1='10.1.0.169'
refdevice2='192.168.184.40'
portrefdev1=1612
portrefdev2=161
credential_dev1="$refdevice1:$portrefdev1:public"
credential_dev2="$refdevice2:$portrefdev2:public"
#git log --pretty=format:'%ci %cn %H' -n 1
version='2019-03-04 08:42:44 +0100 parlos 5be8c80312d166e4e6b7dc703c3e6423f408fd03'
echo "...................................."
echo $(date) . "Starting the evaluation of A2."
echo "...................................."
echo "This is version"
echo "$version"
echo " "
echo "Check cpu type, needs to be 64 bit..."
cpustat=$(lscpu | grep 'op-mode' | grep '64-bit')
if [[ "$cpustat" ]]; then
    echo " 64-bit seems present.";
else
    echo "ERROR: You need to run this on a 64-bit system. As it will do 64-bit arithmetic."
    exit 1;
fi
echo "Checking Correct sample count"
echo "Working with this;"
printf "\t refdevice1 $refdevice1 \n";
printf "\t refdevice2 $refdevice2 \n";
printf "\t credref1   $credential_dev1 \n";
printf "\t credref2   $credential_dev2 \n";
if [ ! -e ./prober.py ]; then
    echo "Error: The test folder, ./, does not contain the executable 'prober.py'. ";
    echo "Folder contains:"
    ls .
    echo "        No point in continuing, leaving."
    exit 1
fi
if [ ! -x ./prober.py ]; then
    echo "Error: ./prober.py does not have the executable bit set. ";
    echo "Folder contains:"
    ls .
    echo "        Leaving."
    exit 1
fi
FileFirstLine=$(head -1 ./prober.py)
SHEbang="${FileFirstLine:0:3}";
if [[ "$SHEbang" == "#!/" ]]; then
    echo "Shebang is present";
else
    echo "Error: Missing shebang."
    echo "Shebang notation is required as to know what engine to use for processing"
    exit 1
fi
##prober.py <Agent IP:port:community> <sample frequency> <samples> <OID1> <OID2> …….. <OIDn>
Ns=$(( ( RANDOM % 10 )  + 10 ));
Fs=1;
chkIF=2;
ooid=$(( chkIF ));
echo "Will collect $credential_dev1  $Ns at $Fs Hz, from $ooid ($chkIF) "
echo "Running:"
echo "./prober.py $credential_dev1 $Fs $Ns 1.3.6.1.4.1.4171.40.$ooid > ./data "
./prober.py $credential_dev1 $Fs $Ns 1.3.6.1.4.1.4171.40.$ooid > ./data
rateCnt=$(cat ./data | wc -l)
sampleCnt="$((rateCnt))"

if [ "$Ns" -ne "$sampleCnt" ]; then 
    echo "Error: Requested $Ns samples; got $sampleCnt". 
    echo "./data"
    cat ./data
    exit 1
else 
    echo " Got $Ns samples."
fi
echo " "
echo "Checking: Sample rate => "
## Get the rate between samples
awk -F'|' 'NR>1{print $1-p} {p=$1}' ./data > ./Trates.log
## Get statistics
read mvalue stdval samples negs <<<$(awk '{ for(i=1;i<=NF;i++) if ($i>0) {sum[i] += $i; sumsq[i] += ($i)^2;} else {de++;} } END {for (i=1;i<=NF;i++) { printf "%g %g %d %d\n", sum[i]/(NR-de), sqrt((sumsq[i]-sum[i]^2/(NR-de))/(NR-de)), (NR-de), de} }' ./Trates.log )
echo "Time: $mvalue +-$stdval from $samples samples. "
#sampleDiff=$((mvalue-Fs)) 
sampleDiff=$(echo $mvalue - $Fs | bc -l )
echo "Will compare $mvalue to $Fs . "
relDiff=$(awk -v a=$mvalue -v b=$Fs -v threshold=0.1 'BEGIN { d=((b-sqrt(a^2))/b)*100; if ( d<threshold ) {print "OK", d } else {print "NOT", d }   }')
if [[ $relDiff == *"OK"* ]]; then
    echo "OK; Sample rate seems reasonable, less than 0.1% difference ($mvalue vs $Fs) "
    echo "$relDiff"
else
    echo "Error: Requested $Fs got $mvalue, thats more than 0.1% difference."
    echo "$relDiff"
    exit 1
fi
## Get the rate between samples
echo " "
echo "Checking data rate (random) " 
awk -F'|' '{print $2}' ./data > ./rates.log
##Get the current reference counters
echo "curl -s http://$refdevice1/counters.conf >  ./counters.conf"
curl -s http://$refdevice1/counters.conf >  ./counters.conf
## Get counter rate
OidC=$(grep "^$chkIF," ./counters.conf | awk -F',' '{print $2}')
## Get statistics
read mvalue stdval samples negs <<<$(awk '{ for(i=1;i<=NF;i++) if ($i>0) {sum[i] += $i; sumsq[i] += ($i)^2;} else {de++;} } END {for (i=1;i<=NF;i++) { printf "%d %d %d %d\n", sum[i]/(NR-de), sqrt((sumsq[i]-sum[i]^2/(NR-de))/(NR-de)), (NR-de), de} }' ./rates.log )
rateDiff=$(awk -v a=$mvalue -v b=$OidC -v threshold=1 'BEGIN { d=((a-b)/a)*100; if ( d<threshold ) {print "OK", d } else {print "NOT", d }   }')
echo "Rates: $mvalue +-$stdval from $samples, with $rateDiff ."
if [[ "$rateDiff" == *"OK"* ]]; then 
    echo "Ok, rate matches ($mvalue vs $OidC)."
else
    echo "Error: Requested $OidC got $mvalue du/tu, thats more than 1% difference"
    echo "this is your data."
    cat ./data
    exit 1
fi
echo " "
echo "Checking that we can atleast manage 2Hz"
echo "Running; prober.py $credential_dev1 2 20 1.3.6.1.4.1.4171.40.$ooid > ./fastprobe "
startTime=$(date +%s)
./prober.py $credential_dev1 2 20 1.3.6.1.4.1.4171.40.$ooid > ./fastprobe
endTime=$(date +%s)
duration=$((endTime-startTime))
echo "That should have taken (approx) 10s. It took, $endTime-$startTime = $duration s. "
if [[ "$duration" -lt 9 ]]; then
    echo "Error: To send 20 requests at 2Hz should have taken arround 10s, you did it in $duration s". 
    echo "Here is a log of your output"
    head ./fastprobe
    exit 1
else
    echo "OK"
fi
echo " "
echo "Checking: data rate (high), nasty agent "
echo "./prober.py $credential_dev1 $Fs $Ns 1.3.6.1.4.1.4171.40.17 > ./high_data" 
./prober.py $credential_dev1 $Fs $Ns 1.3.6.1.4.1.4171.40.17 > ./high_data
echo "Got " $(wc -l ./high_data) " samples "
awk -F'|' '{print $2}' ./high_data > ./high_rates.log
chkIF=17;## Get counter rate
OidC=$(grep "^$chkIF," ./counters.conf | awk -F',' '{print $2}')
##check if negative rate is found
negrate=$(grep '-' ./high_rates.log)
if [[ "$negrate" ]]; then
    echo " (wrap) "
    echo " ERROR: Your solution does not handle 64bit counters wrapping, found a negative rate.."
    echo "$negrate "
    echo " "
    exit 1
fi
linesNotMatching=$(awk -v a=$OidC '{print $1-a}' ./high_rates.log | grep -v -e '^0' | wc -l )
echo "Found $linesNotMatching lines not matching the expected value"
if (( "$linesNotMatching" > 0 )) ; then
    echo "Error: Atleast one rate does not match, $linesNotMatching "
    cat ./high_rates.log
    exit 1
else 
    echo "High-rates; seems ok. "
    echo "Grabbed $Ns samples, there were $linesNotMatching lines not matching the expected $OidC. "
    echo "There were $negrate negative rates collected."
fi
rm ./blob
echo ""
echo "Checking:  Requests, against a -REAL- device. "
echo "Running:  sudo tcpdump -c 20 -w ./blob.pcap -i $internetNIC2 host $refdevice2 and udp &"
#echo "Checking blob1";ls -la ./blob
## Get snmp requests
sudo tcpdump -c 20 -w ./blob.pcap -i $internetNIC2 host $refdevice2 and udp &
echo "tcpdump on"
sleep 3
#echo "Checking blob2";ls -la ./blob
echo "Running ./prober.py $credential_dev2 1 10 1.3.6.1.2.1.2.2.1.10.14" 
./prober.py $credential_dev2 1 10 1.3.6.1.2.1.2.2.1.10.14
sleep 1 
#echo "Checking blob3"; ls -la ./blob
tcpdump -c 10 -ttt -r ./blob.pcap -n ip dst $refdevice2 and udp and dst port $portrefdev2 > ./blob
printf "Requests sent, logged, validating\n" 
read avg stdev samps <<<$(awk '{print $1}' ./blob | awk -F':' 'NR>1{print $3}' | awk '{sum+=$1;sumsq+=($1)^2;n++;} END {printf "%f %f %d\n",sum/n, sqrt((sumsq-sum^2/(n))/(n)),n} ' )
printf "Inter request time; Mean: $avg Stddev: $stdev N: $samps"
stdCheck=$(echo $stdev'<0.1'|bc -l)
if [ "$stdCheck" -eq "0" ]; then
    echo "The std.dev is a bit high, $stdev  vs required 0.1"
    echo "Target average was 1.0 s yours was $avg s".
    echo "Data found in blob"
    exit 1
else
    echo "Nice request stability; $stdev vs required 0.1"
fi
printf "Checking that the prober contains ALL OIDS in one request."
sudo tcpdump -c 1 -ttt -n -i $internetNIC2 ip dst $refdevice2 and udp and dst port  $portrefdev2 > ./blob &
echo "tcpdump on"
sleep 3
echo ".1.3.6.1.2.1.1.3.0" > ./myOids
echo ".1.3.6.1.2.1.2.2.1.10.3" >> ./myOids
echo ".1.3.6.1.2.1.2.2.1.16.3" >> ./myOids
echo ".1.3.6.1.2.1.2.2.1.10.4" >> ./myOids
echo ".1.3.6.1.2.1.2.2.1.16.4" >> ./myOids
echo "Running: ./prober.py $credential_dev2 1 1 1.3.6.1.2.1.2.2.1.10.3 1.3.6.1.2.1.2.2.1.16.3 1.3.6.1.2.1.2.2.1.10.4 1.3.6.1.2.1.2.2.1.16.4 "
./prober.py $credential_dev2 1 1 1.3.6.1.2.1.2.2.1.10.3 1.3.6.1.2.1.2.2.1.16.3 1.3.6.1.2.1.2.2.1.10.4 1.3.6.1.2.1.2.2.1.16.4
sleep 3
echo "tcp done, we hope". 
awk '{out=""; for(i=7;i<=NF;i++){printf "%s\n",$i};}' ./blob > ./oidsInReq
if [ $(diff ./myOids ./oidsInReq|wc -l) -ne 0 ]; then 
    echo "There is a discrepancy betweeen what was requested, and was detected"
    echo "I requested these; got these"
    diff -y ./myOids ./oidsInReq 
    exit 1
else
    echo "All OIDS are present, no extra no missing."
fi
echo " "
echo "Checking SNMP requests, against not so nice device (delay)"
## Get snmp requests
echo "Running "
echo "Will grab request and response, then filter requests to a specific file"
echo "tcpdump -c 20 -w ./blob_delay_all -n -i $internetNIC1 host $refdevice1 and udp and port $portrefdev1 "
sudo tcpdump -c 20 -w ./blob_delay_all -n -i $internetNIC1 host $refdevice1 and udp and port $portrefdev1 &
echo "tcpdump on"
sleep 3
echo "./prober.py $credential_dev1 0.5 10 1.3.6.1.4.1.4171.40.19"
./prober.py $credential_dev1 0.5 10 1.3.6.1.4.1.4171.40.19
echo "Grabbing requests shiping to blob_delay_nsnd, all data in blob_delay_nsnd_all_data"
echo "sudo tcpdump -ttt -n -r ./blob_delay_all ip dst $refdevice1 udp and dst port $portrefdev1 > ./blob_delay_nsnd"  
sudo tcpdump -ttt -n -r ./blob_delay_all ip dst $refdevice1 and udp and dst port $portrefdev1 > ./blob_delay_nsnd  
echo "sudo tcpdump -ttt -n -r ./blob_delay_all > ./blob_delay_nsnd_all_data  "
sudo tcpdump -ttt -n -r ./blob_delay_all > ./blob_delay_nsnd_all_data  
echo "blob_delay size:  " $(wc -l ./blob_delay_nsnd) " lines"
echo "Requests sent, logged, now validating" 
##Wait for file to fill, or quit. 
timeOut=0
while [ ! -s ./blob_delay_nsnd ]; do
    fs=$(wc -c ./blob_delay_nsnd)
    echo $( date +"%Y-%M-%d %H:%m:%S") " Waiting [$timeOut] for trace to arrive, current $fs bytes" 
    sleep 1
    ((timeOut++))
    if [[ "$timeOut" -gt "10" ]]; then
    echo $( date +"%Y-%M-%d %H:%m:%S") " Waited long enough, giving up."
    echo " ERROR did not get packets in trace file within $timeOut s. "
    exit 1
    fi
done
read avg stdev samps <<<$(awk '{print $1}' ./blob_delay_nsnd | awk -F':' 'NR>1{print $3}' | awk '{sum+=$1;sumsq+=($1)^2;n++;} END {printf "%f %f %d\n",sum/n, sqrt((sumsq-sum^2/(n))/(n)),n} ' )
echo "Mean: $avg Stddev: $stdev N: $samps"
stdCheck=$(echo $stdev'<0.1'|bc -l)
avgDiff=$(echo $avg - 2 | bc -l )
echo "Checking average, avgDiff = $avgDiff"
if [[ "$avgDiff" = *'-'* ]]; then
    avgCheck=$(echo '(-1)*'$avgDiff'<0.1'| bc -l )
else
    avgCheck=$(echo $avgDiff'<0.1'| bc -l )
fi
if [ "$avgCheck" -eq "0" ]; then
    echo "Average was not ok, your was $avg the expected was 2."
    exit 1;
fi
if [ "$stdCheck" -eq "0" ]; then
    echo "The std.dev is a bit high, $stdev  vs required 0.1"
    echo "Target average was 2.0 s yours was $avg s".
    echo "Data is in blob_delay_nsnd and blob_delay_nsnd_all_data"
    exit 1
else
    echo "Nice request stability; $stdev vs required 0.1"
fi
echo " "
echo "Checking SNMP requests, against not so nice device (bad response)"
## Get snmp requests
sudo tcpdump -c 10 -ttt -n -i $internetNIC1 ip dst $refdevice1 and udp and dst port $portrefdev1  > /tmp/A2/blob &
echo "tcpdump on"
sleep 3
/tmp/A2/prober $credential_dev1 1 10 1.3.6.1.4.1.4171.40.20
echo "Requests sent, logged, now validating" 
read avg stdev samps <<<$(awk '{print $1}' /tmp/A2/blob | awk -F':' 'NR>1{print $3}' | awk '{sum+=$1;sumsq+=($1)^2;n++;} END {printf "%f %f %d\n",sum/n, sqrt((sumsq-sum^2/(n))/(n)),n} ' )
echo "Mean: $avg Stddev: $stdev N: $samps"
stdCheck=$(echo $stdev'<0.1'|bc -l)
if [ -z "$stdCheck" ]; then 
    echo "An issue with stdCheck = $stdCheck, which means blob issue. "
    echo "There are " . $(wc -l /tmp/A2/blob) . " lines of data."
    exit 1
else
    if [ "$stdCheck" -eq "0" ]; then
	echo "The std.dev is a bit high, $stdev  vs required 0.1"
	echo "Target average was 1.0 s yours was $avg s".
	exit 1
    else
	echo "Nice request stability; $stdev vs required 0.1"
    fi
fi
echo "---------------------------------"
echo "If no issues poped up.. :thumbsup:"
echo "---------------------------------"
#rm /tmp/A2/blob /tmp/A2/counters.conf /tmp/A2/data /tmp/A2/myOids /tmp/A2/oidsInReq /tmp/A2/rates.log /tmp/A2/Trates.log