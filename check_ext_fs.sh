#!/bin/bash

WARNING_DAYS=10
CRITICAL_DAYS=0
WARNING_COUNT=5
CRITICAL_COUNT=0
VERBOSE=0

function help {
	echo "Usage:"
	echo ""
	echo "	$0 [-w days] [-c days] [-W count] [-C count]"
	echo ""
	echo "Options:"
	echo "-h"
	echo "	Print detailed help"
	echo "-v"
	echo "  Verbose output (print status of all filesystems in case of OK"
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

while getopts "w:c:W:C:vh" args; do
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
		v) VERBOSE=1
			;;
	esac
done

STATUS=0
STATUS_COUNT=0
STATUS_MSG=""
VERBOSE_LOG=""

function register_problem {
	givenStatus=$1
	givenMsg=$2

	if [ $givenStatus -gt $STATUS ]; then
		STATUS=$givenStatus
		STATUS_COUNT=0
		STATUS_MSG=""
	fi
	if [ $givenStatus -ge $STATUS ]; then
		((STATUS_COUNT++))
		STATUS_MSG="${STATUS_MSG}${givenMsg}\n"
	fi
}

disk_checked_count=0
disk_ignored_count=0
for DISK in `mount | grep -P 'type ext[2-4] ' | cut -d' ' -f1 | sort`
do
	dumpe2fs_res=`sudo /sbin/dumpe2fs -h ${DISK} 2>/dev/null`
	check_interval=`echo "${dumpe2fs_res}" | grep 'Check interval:' | grep -oP '\-?[0-9]+' | head -n1`
	next_check=`echo "${dumpe2fs_res}" | grep 'Next check after:' | cut -d: -f2- | sed -e 's/^[[:space:]]*//'`
	days_left=$[(`date -d "${next_check}" '+%s'` - `date '+%s'`) / 60 / 60 / 24]
	mount_count=`echo "${dumpe2fs_res}" | grep 'Mount count:' | grep -oP '[0-9]+'`
	mount_max=`echo "${dumpe2fs_res}" | grep 'Maximum mount count:' | grep -oP '\-?[0-9]+'`
	mounts_left=$[mount_max - mount_count]

	if [ $check_interval -gt 0 ] && [ $days_left -le $CRITICAL_DAYS ]; then
		register_problem 2 "only ${days_left} days left for ${DISK}"
	fi
	if [ $mount_max -gt 0 ] && [ $mounts_left -le $CRITICAL_COUNT ]; then
		register_problem 2 "only ${mounts_left} mounts left for ${DISK}"
	fi
	if [ $check_interval -gt 0 ] && [ $days_left -le $WARNING_DAYS ]; then
		register_problem 1 "only ${days_left} days left for ${DISK}"
	fi
	if [ $mount_max -gt 0 ] && [ $mounts_left -le $WARNING_COUNT ]; then
		register_problem 1 "only ${mounts_left} mounts left for ${DISK}"
	fi
	if [ $check_interval -gt 0 ] || [ $mount_max -gt 0 ]; then
		VERBOSE_LOG="${VERBOSE_LOG}${DISK}: ${days_left} days left; ${mounts_left} mounts left\n"
		((disk_checked_count++))
	else
		VERBOSE_LOG="${VERBOSE_LOG}${DISK}: ignored\n"
		((disk_ignored_count++))
	fi
done

if [ $STATUS -eq 0 ]; then
	echo "OK (${disk_checked_count} filesystems checked, ${disk_ignored_count} filesystems ignored)"
	if [ $VERBOSE -eq 1 ]; then
		VERBOSE_LOG=`echo -e "${VERBOSE_LOG}" | sed -e 's/[[:cntrl:]]$//'`
		echo -e "${VERBOSE_LOG}"
	fi
	exit $STATUS
else
	if [ $STATUS -eq 1 ]; then
		echo -n "WARNING"
	else
		echo -n "CRITICAL"
	fi
	STATUS_MSG=`echo -e "${STATUS_MSG}" | sed -e 's/[[:cntrl:]]$//'`
	if [ $STATUS_COUNT -eq 1 ]; then
		echo " - ${STATUS_MSG}"
	else
		echo -e " - ${STATUS_COUNT} problems\n${STATUS_MSG}"
	fi
	exit $STATUS
fi

