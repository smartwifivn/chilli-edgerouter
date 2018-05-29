#!/bin/sh
#run=/opt/vyatta/bin/vyatta-op-cmd-wrapper
CPU_ARCH=`uname -m`

dpkg -s coova-chilli &> /dev/null

if [ $? -eq 1 ]; then
  if [ "$CPU_ARCH" == "mips64" ]; then
      curl http://config.smartwifi.vn/edgerouter/libssl0.9.8_0.9.8o-4squeeze14_mips.deb -o /tmp/libssl0.9.8_0.9.8o-4squeeze14_mips.deb
      curl http://config.smartwifi.vn/edgerouter/coova-chilli_1.3.0_mips.deb -o /tmp/coova.deb
      dpkg -i /tmp/libssl0.9.8_0.9.8o-4squeeze14_mips.deb
  else
      curl http://config.smartwifi.vn/edgerouter/coova-chilli_1.3.1.4_mipsel.deb -o /tmp/coova.deb
  fi

  dpkg -i /tmp/coova.deb
fi
UAMHOMEPAGE=""
WHITELABEL="http:\/\/cloud.smartwifi.vn/splash/prelogin"

#read -p "Which interface is your WAN [eth0]? " WAN
#[ -z $WAN ] && WAN=eth0
LAN_INTERFACES=$(ifconfig | grep Link | grep encap | awk '{print $1}' | sed '/lo/d' | sed '/ppp*/d' | sed '/tun*/d' | sed '/imq*/d')
echo "Available interfaces:"
echo $LAN_INTERFACES
read -p "Which interface is used for hotspot [eth2]? " WLAN
[ -z $WLAN ] && WLAN=eth2

NETWORK="172.16.0"
GATEWAYMAC=`ifconfig eth0 | awk '/HWaddr/ { print $5 }' | sed 's/:/-/g'`

mkdir /etc/chilli/$WLAN
mkdir /etc/chilli/$WLAN/walled-garden

if [ ! -f /usr/bin/smartwifi ]; then
  curl http://config.smartwifi.vn/edgerouter/smartwifi -o /usr/bin/smartwifi
  chmod a+x /usr/bin/smartwifi
fi

echo "include /etc/chilli/$WLAN/main.conf
include /etc/chilli/$WLAN/hs.conf
include /etc/chilli/$WLAN/local.conf
ipup /etc/chilli/up.sh
ipdown /etc/chilli/down.sh" > /etc/chilli/$WLAN/chilli.conf
[ -f /etc/chilli/defaults ] && rm /etc/chilli/defaults
[ -f /etc/chilli/hs.conf ] && rm /etc/chilli/hs.conf
[ -f /etc/chilli/local.conf ] && rm /etc/chilli/local.conf
[ -f /etc/chilli/main.conf ] && rm /etc/chilli/main.conf

curl -o /etc/chilli/$WLAN/config http://config.smartwifi.vn/edgerouter/eth2/defaults

sed -i "/HS_UAMDOMAINS/d" /etc/chilli/$WLAN/config
echo "HS_UAMDOMAINS=\".smartwifi.vn .smartwifi.com.vn\"" >> /etc/chilli/$WLAN/config

#sed -i "/HS_NASID/d" /etc/chilli/$WLAN/config
#echo "HS_NASID=$GATEWAYMAC" >> /etc/chilli/$WLAN/config

# sed -i -e "/HS_NASID/d" /etc/chilli/$WLAN/config
# echo "HS_NASMAC=$GATEWAYMAC" >> /etc/chilli/$WLAN/config

# sed -i "/HS_WANIF/d" /etc/chilli/$WLAN/config
sed -i "/HS_LANIF/d" /etc/chilli/$WLAN/config
# echo "HS_WANIF=$(route | grep default | grep 0.0.0.0 | awk '{print $8}')" >> /etc/chilli/$WLAN/config
echo "HS_LANIF=$WLAN" >> /etc/chilli/$WLAN/config

curl -o /etc/heartbeat.sh http://config.smartwifi.vn/edgerouter/heartbeat.sh
chmod 755 /etc/heartbeat.sh

crontab -l > /tmp/mycron
sed -i '/heartbeat/d' /tmp/mycron
sed -i '/shutdown/d' /tmp/mycron
sed -i '/checkrunning/d' /tmp/mycron
echo "*/5 * * * * /etc/heartbeat.sh $GATEWAYMAC" >> /tmp/mycron
echo "0 5 * * * /sbin/shutdown -r now" >> /tmp/mycron
echo "*/3 * * * * /etc/init.d/chilli checkrunning" >> /tmp/mycron
crontab /tmp/mycron
rm /tmp/mycron

cp /etc/default/chilli /etc/default/chilli.tmp
cat /etc/default/chilli.tmp | sed "s/START_CHILLI=0/START_CHILLI=1/g"  > /etc/default/chilli
rm /etc/default/chilli.tmp

ln -s /etc/init.d/chilli /etc/rc2.d/S90chilli
ln -s /etc/init.d/chilli /etc/init.d/smartwifi

/usr/bin/smartwifi update

source /opt/vyatta/etc/functions/script-template
configure
set system time-zone Asia/Ho_Chi_Minh
delete interfaces ethernet $WLAN address
commit
save

echo "Please add the following MAC address to your account"
echo "Gateway MAC: $GATEWAYMAC"
/usr/bin/smartwifi enable facebook_js
/etc/init.d/chilli start

exit
