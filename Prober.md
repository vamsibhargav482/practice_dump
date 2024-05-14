
To run the script we run the following in terminal, ensuring all the necessary packages are available 
in unix: 
###The script will be invoked as follows:  

``` prober <Agent IP:port:community> <sample frequency> <samples> <OID1> <OID2> ……... <OIDn> ```   
and example would look something like this one

``` python3 <Filename> 18.219.51.6:1611:public 1 10 1.3.6.1.4.1.4171.40.1 ```

IP, port, and community are agent details,  
OIDn are the OIDs to be probed (they are absolute, cf. IF-MIB::ifInOctets.2 for interface 2, or 1.3.6.1.2.1.2.2.1.10.2 [1])   
Sample frequency (Fs) is the sampling frequency expressed in Hz, you should handle between 10 and 0.1 Hz.  
Samples (N) is the number of successful samples the solution should do before terminating; hence the value should be greater or equal to 2. If the value is -1 that means run forever (until CTRL-C is pressed, or the app is terminated in some way).  

###To test your script you can make use of the test.sh to test your script 
test.sh is a shell script from A3 testing environment, it is modified to test locally in order to run the test you need to have your file named prober.py in same directory where the test file is and in ubuntu terminal use 
``` ./test.sh to run the script ``` 
