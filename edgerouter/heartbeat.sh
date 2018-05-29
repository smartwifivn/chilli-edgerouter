#/bin/sh
#
KEY=xpHWD7YbSYfTnNWW
DEVICE_SERVER='http://cloud.smartwifi.vn'
RANDOM_STR=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c${1:-32})
TMP_CONFIG_FILE='/tmp/sm_setup'
AUTO_FETCH=0

if [ -z "$1" ]
then
    mac=$(sudo ifconfig eth0 |grep HWaddr|awk '{print $5}' | sed 's/:/-/g')
else
    mac=$1
fi

type=$(cat /proc/cpuinfo | grep machine | awk '{print $4}' | sed 's/\//_/g')
load=$(cat /proc/loadavg | awk '{print $2}')
localtime=$(date +%s)
uptime=$(cat /proc/uptime | awk '{print $1}')
associated=$(sudo chilli_query list | awk '{print $6}' | wc -l)
notauthenticated=$(sudo chilli_query list | awk '{print $6}' | grep '-' | wc -l)
online=$((associated - notauthenticated))
TOTALMEM=$(cat /proc/meminfo | head -1 | awk {'print $2'})
FREEMEM=$(cat /proc/meminfo | head -2 | tail -1 | awk {'print $2'})

code=$(echo -n "$KEY$mac$localtime" | md5sum | awk '{print $1}')
CURRENT_CONFIG_VERSION=0

fetch_config(){
    /usr/bin/curl -s "$DEVICE_SERVER/devices/apis/fetch_config?mac=$2&state=$1" -o $TMP_CONFIG_FILE

    #Check config file
    [ -f $TMP_CONFIG_FILE ] && {
        STATE=$(cat $TMP_CONFIG_FILE | grep HS_STATE | awk -F'=' '{print $2}')
        CONFIG_VERSION=$(cat $TMP_CONFIG_FILE | grep CONFIG_VERSION | awk -F'=' '{print $2}')
    }

    [ -f $TMP_CONFIG_FILE ] && [ -s $TMP_CONFIG_FILE ] && [ "$STATE" = "$1" ] && {
        chmod +x $TMP_CONFIG_FILE

        $TMP_CONFIG_FILE

        sleep 3
        rm $TMP_CONFIG_FILE
       }
 }

res=$(/usr/bin/curl -s "$DEVICE_SERVER/devices/apis/ping?type=$type&mac=$mac&load=$load&online=$online&uptime=$uptime&localtime=$localtime&code=$code&freemem=$FREEMEM&totalmem=$TOTALMEM") #> /dev/null 2>&1
#echo $res
if test $res -ne $CURRENT_CONFIG_VERSION
then
    #echo "New config found"
    [ "$AUTO_FETCH" = "1" ] && {
        fetch_config $RANDOM_STR $mac
    }
fi
