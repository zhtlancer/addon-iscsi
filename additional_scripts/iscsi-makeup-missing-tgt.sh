#!/bin/bash

read -p "Use this script with extreme caution. If you know extractly what you are doing, enter YES: "
if [[ ! $REPLY = "YES" ]]
then
	exit 1
fi

TARGET_FILE=`mktemp`
DB_FILE=`mktemp`
HOST_RANGE=`seq 99 200`

ssh 10.10.0.15 "sudo tgtadm --lld iscsi --op show --mode target" | grep "^Target" > $TARGET_FILE
python image-get-datastore-list.py >$DB_FILE

for i in $HOST_RANGE
do
	echo "Host 10.10.0.$i"
	echo "In HOST session list, not in HEAD target list & Datastore image database:"
	for s in `ssh 10.10.0.$i "sudo iscsiadm -m session" 2>/dev/null | awk '{print $4}'`
	do
		ids=`echo $s | grep -o "[0-9]\+-[0-9]\+$" | sed 's/-/ /'`
		if [ -z "$ids" ]
		then
			ids=`echo $s | grep -o "[0-9]\+$"`
		fi
		grep "\<$s\>" $TARGET_FILE >/dev/null || grep "\<$ids\>" $DB_FILE >/dev/null || echo "$s"
	done

	echo "In HOST session list & Datastore image database, not in HEAD target list:"
	for s in `ssh 10.10.0.$i "sudo iscsiadm -m session" 2>/dev/null | awk '{print $4}'`
	do
		ids_dash=`echo $s | grep -o "[0-9]\+-[0-9]\+$"`
		ids=`echo $s | grep -o "[0-9]\+-[0-9]\+$" | sed 's/-/ /'`
		if [ -z "$ids" ]
		then
			ids_dash=`echo $s | grep -o "[0-9]\+$"`
			ids=`echo $s | grep -o "[0-9]\+$"`
		fi
		grep "\<$s\>" $TARGET_FILE >/dev/null || (grep "\<$ids\>" $DB_FILE >/dev/null && echo "$s" && ssh 10.10.0.15 "sudo tgt-setup-lun-one -d /dev/zvol/cloud/opennebula/persistent/lv-one-$ids_dash -n $s" && ssh 10.10.0.15 "sudo tgt-admin --dump | sudo tee /etc/tgt/targets.conf >/dev/null")
	done

	echo "In HOST session list & HEAD target list, not in Datastore image database:"
	for s in `ssh 10.10.0.$i "sudo iscsiadm -m session" 2>/dev/null | awk '{print $4}'`
	do
		ids=`echo $s | grep -o "[0-9]\+-[0-9]\+$" | sed 's/-/ /'`
		if [ -z "$ids" ]
		then
			ids=`echo $s | grep -o "[0-9]\+$"`
		fi
		grep "\<$ids\>" $DB_FILE >/dev/null || (grep "\<$s\>" $TARGET_FILE >/dev/null && echo "$s")
	done

done

rm -f $TARGET_FILE
rm -f $DB_FILE
