#!/bin/sh

TOKEN=$1
DOMAIN_ID=$2
SUB_DOMAIN=$3
MAIN_DOMAIN=$4
DOMAIN=${SUB_DOMAIN}.${MAIN_DOMAIN}

NOW_IP=`nslookup ${DOMAIN} 119.29.29.29 | grep -Po '[\w:]+:+[\w:]+'` && \
echo "Now ip of ${DOMAIN} is ---${NOW_IP}---" && \
echo ${NOW_IP} > /root/nowIp.txt && \
# check now ip useable
rm -f /root/nowIp.csv && \
/root/CloudflareST -tl 200 -tll 2 -sl 5 -p 1 -f /root/nowIp.txt -o "/root/nowIp.csv" >/dev/null 2>&1 && \
test_ip=`grep -s -Po '[\w:]+:+[\w:]+' /root/nowIp.csv| head -n 1` && \
test_speed=`awk -F, 'NR==2{print $6}' /root/nowIp.csv` && \
if [ ! -n "$test_ip" ] || [ `echo "$test_speed < 5.00" | bc` -eq 1 ]; then
   echo "now ip unavailable, continue"
else
   date
   echo "now ip available, no need to change"
   exit
fi && \
   
rm -f /root/result.csv && \
/root/CloudflareST -tl 200 -tll 2 -sl 5 -p 1 -f /root/ipv6.txt >/dev/null 2>&1 && \
target_ip=`grep -s -Po '[\w:]+:+[\w:]+' /root/result.csv| head -n 1` && \
if [ ! -n "$target_ip" ]; then
   echo "fail to found a target ip"
   exit
else
   echo "find a target IP $target_ip"
fi && \
RECORD_ID=`curl -s -X POST https://dnsapi.cn/Record.List -d 'login_token='"${TOKEN}"'&format=json&domain_id='"${DOMAIN_ID}"'&sub_domain='"${SUB_DOMAIN}"'&offset=0&length=3' | jq -r '.records' | grep -E -o '[0-9]{5,15}'`
if [ $? -ne 0 ]; then
    echo "docker can't connect to internet, check your iptables or restart the docker program(not only this container) especially when you had restart other proxy process"
    exit
else
    echo "RECORD_ID is $RECORD_ID"
fi && \

if [ "${target_ip}" = "${NOW_IP}" ]; then
   echo "Domain IP not changed."
   exit 
fi && \

echo "start ddns refresh" && \
curl -X POST https://dnsapi.cn/Record.Ddns -d 'login_token='"${TOKEN}"'&format=json&domain_id='"${DOMAIN_ID}"'&record_id='"${RECORD_ID}"'&record_line_id=0&&record_type=AAAA&value='"${target_ip}"'&sub_domain='"${SUB_DOMAIN}"'' | jq && \
if [ $? -ne 0 ]; then
    echo "ddns refresh fail, check your token or domain input"
    exit
else
    echo "Finished"
fi && \
exit 0
