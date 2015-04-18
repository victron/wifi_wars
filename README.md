# Wifi Wars

---
It's not tolerant to deauthenticate someone, but it's also not tolerant to set wifi power on max and buy crazy powered routers.

===
currently working on same channel as ```wlan0``` and it looks it's enogh.
## Oriented to work on openwrt
### Requirements
- need to install aircrack-ng in /tmp
normally with ```-d ram``` option
- copy it in ```/usr/sbin/``` (actualy only aireplay-ng)
with libs
- find needed libs with ``` ldd```

#### same pre-requirements need to do with ```horst```
### Generally script done:
- create ```mon0``` interface
- put it in up state
- collect monitoring with ```horst```
- select most noisy BSSID
- start ```aireplay-ng -0 100 -a 00:90:90:F8:30:34 mon0```

