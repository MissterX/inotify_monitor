#!/bin/bash

SCRIPT_DIR=$(echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")
DATABASE=$SCRIPT_DIR/monitored_files.sqlite

# Get the constants.
LIST=$(sqlite3 "$DATABASE" "SELECT cname, cvalue FROM file_constants")

# For each row
for ROW in $LIST; do

  # Parsing data (sqlite3 returns a pipe separated string)
  cname=$(echo "$ROW" | awk '{split($0,a,"|"); print a[1]}')
  cvalue=$(echo "$ROW" | awk '{split($0,a,"|"); print a[2]}')

  # Create constants and their value.
  eval "$cname='$cvalue'"
done

# Get the last line of logfile.
tail -fn0 "$LOG_FILE" | \
while read line ; do
  # Put a copy to syslog.
  # Call the external program that should
  # react on events.
  logger INOTIFY_MONITOR: $EXTERNAL_PROG $line

  $EXTERNAL_PROG $line
done
