#!/bin/bash

WARNING_DAYS=10
CRITICAL_DAYS=0
WARNING_COUNT=5
CRITICAL_COUNT=0

function help {
	echo "Usage:"
	echo ""
	echo "	$0 [-w days] [-c days] [-W count] [-C count]"
	echo ""
	echo "Options:"
	echo "-h"
	echo "	Print detailed help"
	echo "-w INTEGER"
	echo "	Exit with WARNING status if less than INTEGER days before a full check (default: 10)"
	echo "-c INTEGER"
	echo "	Exit with CRITICAL status if less than INTEGER days before a full check (default: 0)"
	echo "-W INTEGER"
	echo "	Exit with WARNING status if less than INTEGER mounts left before a full check (default: 5)"
	echo "-C INTEGER"
	echo "	Exit with CRITICAL status if less than INTEGER mounts left before a full check (default: 0)"
	exit 0
}

while getopts "w:c:W:C:h" args; do
	case $args in
		h) help
			;;
		w) WARNING_DAYS=$OPTARG
			;;
		c) CRITICAL_DAYS=$OPTARG
			;;
		W) WARNING_COUNT=$OPTARG
			;;
		C) CRITICAL_COUNT=$OPTARG
			;;
	esac
done

for DISK in `mount | grep -P 'type ext[2-4] ' | cut -d' ' -f1`
do
	dumpe2fs_res=`sudo /sbin/dumpe2fs -h ${DISK} 2>/dev/null`
	check_interval=`echo "${dumpe2fs_res}" | grep 'Check interval:' | grep -oP '\-?[0-9]+' | head -n1`
	next_check=`echo "${dumpe2fs_res}" | grep 'Next check after:' | cut -d: -f2- | sed -e 's/^[[:space:]]*//'`
	days_left=$[(`date -d "${next_check}" '+%s'` - `date '+%s'`) / 60 / 60 / 24]
	mount_count=`echo "${dumpe2fs_res}" | grep 'Mount count:' | grep -oP '[0-9]+'`
	mount_max=`echo "${dumpe2fs_res}" | grep 'Maximum mount count:' | grep -oP '\-?[0-9]+'`
	mounts_left=$[mount_max - mount_count]

	if [ $check_interval -gt 0 ] && [ $days_left -le $CRITICAL_DAYS ]; then
		echo "CRITICAL - only ${days_left} days left for ${DISK}"
		exit 2
	fi
	if [ $mount_max -gt 0 ] && [ $mounts_left -le $CRITICAL_COUNT ]; then
		echo "CRITICAL - only ${mounts_left} mounts left for ${DISK}"
		exit 2
	fi
	if [ $check_interval -gt 0 ] && [ $days_left -le $WARNING_DAYS ]; then
		echo "WARNING - only ${days_left} days left for ${DISK}"
		exit 1
	fi
	if [ $mount_max -gt 0 ] && [ $mounts_left -le $WARNING_COUNT ]; then
		echo "WARNING - only ${mounts_left} mounts left for ${DISK}"
		exit 1
	fi
done

echo "OK"

