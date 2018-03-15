#!/bin/bash
# This script was written to do a few things:
# 1. Collect active LVM devices
# 2. Collect active multipath info
# 3. Identify vendor and serial for active LVM devices using sg_inq (sg3_utils requisite)
# 4. Output to a file (that could be swept up for centralized reporting)
# Created Mar 2018 by Dustin Holub

LVSTEMPFILE=/tmp/lvs.out
MPTEMPFILE=/tmp/multipathll.out
DSKVNDTEMPFILE=/tmp/dskvnd.out
HOSTNAME=`hostname`
REPORTFILE=/tmp/$HOSTNAME.diskinfo.out

#gather LVM info
        > $LVSTEMPFILE
        #echo "LogVol VolGroup Size Device" > $LVSTEMPFILE
        /usr/sbin/lvs -o +devices |grep -v Attr|tr -s ' '|cut -d'(' -f1|cut -d' ' -f2,3,5,6 >> $LVSTEMPFILE

#gather multipath info
/sbin/multipath -ll |grep mpath > $MPTEMPFILE

#gather disk vendor and serial info
> $DSKVNDTEMPFILE
for i in `ls /dev/* |egrep "sd|dm-"`
do
        echo "Gathering sg_inq info for $i"
        TMPDISK="$(eval sg_inq $i)"
        if [[ $TMPDISK ]]; then
                VENDOR=`echo "$TMPDISK" |grep "Vendor identification" |tr -d ' '|cut -f2 -d':'`
                PRODUCT=`echo "$TMPDISK" |grep "Product identification" |tr -d ' '|cut -f2 -d':'`
                UNITSER=`echo "$TMPDISK" |grep "Unit serial" |tr -d ' '|cut -f2 -d':'`
                echo "$i $VENDOR $PRODUCT $UNITSER" >> $DSKVNDTEMPFILE
        fi
done


# loop through multipath output into array
# assumes output file has 5 fields
#while IFS= read -r line
#do
#       mpdiskinfo=($line)
#       echo ${mpdiskinfo[@]} #full line in array
#       /usr/bin/sg_inq /dev/${mpdiskinfo[2]} #sg_inq mp device
#
#done < $MPTEMPFILE


#map all LVS devices to disk vendors
DISKVND=`cat $DSKVNDTEMPFILE`
MP=`cat $MPTEMPFILE`
while IFS= read -r line
do
        DISK=`echo $line |awk {'print $4'}`
        if [[ $DISK = *"/dev/sd"* ]]; then      #special case to trim local disks
                DISK=`echo $DISK|sed 's/[0-9]//g'`
        fi
        echo -n "$HOSTNAME "
        echo -n "$line   MPINFO="
        SHORTDISK=`echo $DISK|cut -f3 -d'/'`
        MPINFO=`echo "$MP" | grep "$SHORTDISK "`
        if [[ $MPINFO ]]; then
                echo "$MPINFO"|awk -v ORS="" -F'[[:space:]()]' {'print $1","$3'}
        else
                echo -n "NOTFOUND,NOTFOUND"
        fi
        echo -n " VENDOR= "
        echo "$DISKVND" |grep "$DISK "|awk {'print $2" "$3" "$4'}
done < $LVSTEMPFILE |tee $REPORTFILE






#TODO: Identify any filesystems mounted directly on disks, not via LVM
