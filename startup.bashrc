#!/bin/bash

# Change this as you see fit.
# Directory to monitor as argument to this script.
if [ -z "$1" ]; then
  MONITOR_DIR="/etc"
else
  MONITOR_DIR="$1"
fi

# Should we monitor the directory recursivelly?
# 1 = yes
# 0 = no
MONITOR_REC=1

# Do not monitor this directory.
EXCLUDE_DIR="etc/webmin"

# Events to react on, choose between:
#   access          file or directory contents were read
#   modify          file or directory contents were written
#   attrib          file or directory attributes changed
#   close_write     file or directory closed, after being opened in
#                   writeable mode
#   close_nowrite   file or directory closed, after being opened in
#                   read-only mode
#   close           file or directory closed, regardless of read/write mode
#   open            file or directory opened
#   moved_to        file or directory moved to watched directory
#   moved_from      file or directory moved from watched directory
#   move            file or directory moved to or from watched directory
#   create          file or directory created within watched directory
#   delete          file or directory deleted within watched directory
#   delete_self     file or directory was deleted
#   unmount         file system containing file or directory unmounted
MON_EVENT="modify,move"

# Mime type of monitored file(s) to check.
# Subtype is *not* checked.
MIME_TYPE="text"

# Name of the SQLITE database.
DB_NAME=monitored_files.sqlite

#######################################################################
#                                                                     #
#                Do not change anything below this line.              #
#                                                                     #
#######################################################################

SCRIPT_DIR=$(echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")

. $SCRIPT_DIR/functions.bashrc

echo 
echo "Request for monitoring directory: "$GREEN$MONITOR_DIR$WHITE
echo 

temp_inoty_path=$(type -P "inotifywait")
if [ -z "$temp_inoty_path" ]; then
  VAR_TXT="You do not have inotifywait installed or it is not in your path."
  HOR_COL=$(($TERM_WIDTH - ${#VAR_TXT} - 3))
  echo 
  echo "====================================================="
  echo "= The tool can be downloaded from github:           ="
  echo "=   https://github.com/rvoicilas/inotify-tools/wiki ="
  echo "= or installed from EPEL repository.                ="
  echo "====================================================="
#  printf "$VAR_TXT%*s%s%s\n" $HOR_COL $RED "$TXT_FAILED" $WHITE
  print_mess "FAIL" "$VAR_TXT"
  echo 
  exit 1
else
  VAR_TXT="Checking if \"inotify-tools\" are installed."
  HOR_COL=$(($TERM_WIDTH - ${#VAR_TXT} - 3))
#  printf "$VAR_TXT%*s%s%s%s\n" $HOR_COL $GREEN "$TXT_OK" $WHITE
  print_mess "OK" "$VAR_TXT"
fi

DATABASE=$SCRIPT_DIR/$DB_NAME
LOG_FILE=/var/log/inotify.log
EXTERNAL_PROG=$SCRIPT_DIR/external_prog.bashrc

if [ $MONITOR_REC == 1 ]; then
  recursive="-r"
else
  recursive=""
fi

# Get the path of inotifywait
TEMP=$(type -P inotifywait)
INOTY_PATH=$(dirname "$TEMP")

TABLE1="CREATE TABLE file_path (fid integer primary key autoincrement, cpath varchar(255), cname varchar(100));"
TABLE2="CREATE TABLE file_content (fcid integer primary key autoincrement, content blob, hash varchar(40), version unsigned int, fdate datetime,fid unsigned int, foreign key(fid) references file_path(fid));"
TABLE3="CREATE TABLE file_constants (cid integer primary key autoincrement, cvalue varchar(255), cname varchar(100));"

# Do we have a database?
if [ ! -e "$DATABASE" ]; then
  # Create the db and add structure.
  print_mess "OK" "Creating database."
  echo "$TABLE1" > /tmp/table1
  echo "$TABLE2" > /tmp/table2
  echo "$TABLE3" > /tmp/table3
  touch "$DATABASE"
  print_mess "OK" "Creating database structure."
  sqlite3 "$DATABASE" < /tmp/table1
  sqlite3 "$DATABASE" < /tmp/table2
  sqlite3 "$DATABASE" < /tmp/table3
  rm -f /tmp/table1
  rm -f /tmp/table2
  rm -f /tmp/table3

  # Add some constants
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('MONITOR_DIR', '$MONITOR_DIR');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('SCRIPT_DIR', '$SCRIPT_DIR');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('DATABASE', '$DATABASE');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('LOG_FILE', '$LOG_FILE');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('EXTERNAL_PROG', '$EXTERNAL_PROG');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('MIME_TYPE', '$MIME_TYPE');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('INOTY_PATH', '$INOTY_PATH');"
  sqlite3 "$DATABASE" "INSERT INTO file_constants (cname, cvalue) VALUES ('EXCLUDE_DIR', '$EXCLUDE_DIR');"
  print_mess "OK" "Updated database."

  # Scan files into DB.
  ./scan_files_into_db.bashrc
fi

# Activating kernel file monitoring.
print_mess "OK" "Start of kernel file monitoring."

INOTY_TXT=$("$INOTY_PATH/inotifywait" -d "$recursive" -o "$LOG_FILE" --timefmt "%Y-%m-%d %T" --format "%T %w %f %e" -e "$MON_EVENT" --exclude "$EXCLUDE_DIR" "$MONITOR_DIR" 2> /tmp/errfile)
INOTY_ERR=$(</tmp/errfile)

if [ -z "$INOTY_ERR" ]; then
  # React on logfile changes.
  print_mess "OK" "React on inotifywait logfile changes runs in background."
  nohup "$SCRIPT_DIR/mon_inoty_log.bashrc" 2> /dev/null &
  echo 
  echo "Kernel inotify log -> $LOG_FILE"
  echo "Activity           -> /var/log/messages"
else
  echo 
  echo "====================================================="
  echo "$INOTY_ERR"
  echo "====================================================="
  print_mess "FAIL" "Error while starting!"
  print_mess "FAIL" "inotifywait did not start properly."
  echo 
fi
