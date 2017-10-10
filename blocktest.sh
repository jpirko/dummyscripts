#!/bin/bash

TC=~/iproute2/tc/tc
BLOCK0=222
BLOCK1=333
HANDLESTART=0x1000

function count_filters {
	dev=$1
	ingeng=$2
	expectlines=$3
	lines=$(sudo $TC filter show dev $dev $ingeng | grep "0x" | wc -l)
	if [ "$lines" -eq "$expectlines" ]; then
		echo -n "good: "
	else
		echo -n "bad:  "
	fi
	echo $dev $ingeng rules: $lines 
}  

for i in {0..15}
do
	sudo ip link del testdummy$i 2>/dev/null
done
for i in {0..15}
do
	sudo ip link add testdummy$i type dummy
done

for i in {0..7}
do
	sudo $TC qdisc add dev testdummy$i ingress block $BLOCK0
done

for i in {8..15}
do
	sudo $TC qdisc add dev testdummy$i clsact ingress_block $BLOCK0 egress_block $BLOCK1
done

sudo $TC qdisc

echo Adding rules

for i in {0..15}
do
	handle=$(($HANDLESTART + $i))
	sudo $TC filter add dev testdummy0 ingress protocol ip pref 33 handle $handle flower dst_ip 192.168.0.$i action drop
	sudo $TC filter add dev testdummy8 egress protocol ip pref 33 handle $handle flower dst_ip 192.168.1.$i action drop
done

sudo $TC qdisc del dev testdummy0 ingress
sudo $TC qdisc del dev testdummy8 clsact

count_filters "testdummy7" "ingress" 16
count_filters "testdummy9" "egress" 16

sudo $TC qdisc add dev testdummy0 ingress block $BLOCK0
sudo $TC qdisc add dev testdummy8 clsact ingress_block $BLOCK0 egress_block $BLOCK1

count_filters "testdummy0" "ingress" 16
count_filters "testdummy8" "egress" 16

echo Deleting rules

for i in {0..15}
do
	handle=$(($HANDLESTART + $i))
	sudo $TC filter del dev testdummy7 ingress protocol ip pref 33 handle $handle flower dst_ip 192.168.0.$i action drop
	sudo $TC filter del dev testdummy9 egress protocol ip pref 33 handle $handle flower dst_ip 192.168.1.$i action drop
done

for i in {0..7}
do
	count_filters "testdummy$i" "ingress" 0
done

for i in {8..15}
do
	count_filters "testdummy$i" "ingress" 0
	count_filters "testdummy$i" "egress" 0
done

sudo $TC filter show dev testdummy8 egress

for i in {0..15}
do
	sudo ip link del testdummy$i
done
