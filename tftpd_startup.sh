#!/bin/bash

# Update config file with environment variables
EXEC_OPTIONS="--foreground --user tftp --permissive --blocksize $BLOCKSIZE"
TRUE_LIST=("true" "True" "TRUE" "yes" "Yes" "YES")
WORLD_READ_SET="FALSE"
BLOCKSIZE_SET="FALSE"
for item in ${TRUE_LIST[@]}; do
	if [ "$WRITE_ENABLED" == "$item" ]; then
		EXEC_OPTIONS="$EXEC_OPTIONS --create"
	fi
	if [ "$IPV4_ONLY" == "$item" ]; then
		EXEC_OPTIONS="$EXEC_OPTIONS --ipv4"
	fi
	if [ "$IPV6_ONLY" == "$item" ]; then
		EXEC_OPTIONS="$EXEC_OPTIONS --ipv6"
	fi
	if [ "$WORLD_READABLE" == "$item" ]; then
		WORLD_READ_SET="TRUE"	
	fi
	if [ "$DEBUG" == "$item" ]; then
		EXEC_OPTIONS="$EXEC_OPTIONS --verbose"
	fi
done
if [ "$WORLD_READ_SET" == "TRUE" ]; then
	EXEC_OPTIONS="$EXEC_OPTIONS --umask 0117"
else
	EXEC_OPTIONS="$EXEC_OPTIONS --umask 0557"
fi

# Start rsyslog
echo "`date +'%a %b %d %H:%M:%S %Y'` Starting rsyslogd..."
rsyslogd -n &
RSYSLOG_PID="$!"

# Start tftpd
echo "`date +'%a %b %d %H:%M:%S %Y'` Starting tftpd with options '$EXEC_OPTIONS $DATA_PATH'..."
in.tftpd $EXEC_OPTIONS --secure $DATA_PATH &
TFTP_PID="$!"

echo $TFTP_PID $RSYSLOG_PID
# wait for break
trap 'echo "`date +\"%a %b %d %H:%M:%S %Y\"` stopping tftpd..." && kill $TFTP_PID $RSYSLOG_PID > /dev/null 2&>1' SIGTERM SIGINT
wait