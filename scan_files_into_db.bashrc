#!/bin/bash

#######################################################################
#                                                                     #
#                Do not change anything below this line.              #
#                                                                     #
#######################################################################

SCRIPT_DIR=$(echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")
. $SCRIPT_DIR/functions.bashrc

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

# Scan files.
echo Scanning directory $GREEN$MONITOR_DIR$WHITE for files with mime type: $GREEN$MIME_TYPE$WHITE

shopt -s globstar
for f in $MONITOR_DIR/* $MONITOR_DIR/**/*; do
  # Skip if this is a directory.
  if [ ! -d "$f" ]; then

    # Check if the file has text as main mime type.
    mtype=$(file --mime-type "$f")
    mtypeadj=${mtype//: / }
    main_mime=($mtypeadj)
    mime_type=(${main_mime[1]//// })
    if [ "$MIME_TYPE" = "${mime_type[0]}" ]; then
      fname=$(basename "$f")
      dname=$(dirname "$f")

      # Is last char in dname not a forward slash (/)?
      if [ ! "${dname: -1}" == "/" ]; then
        dname=$dname'/'
      fi

      # Now we have a file, check if it is in db.
      file_in_db=$(sqlite3 "$DATABASE" "SELECT * FROM file_path WHERE cname LIKE '$fname'")

      # If file not in db.
      if [ -z "$file_in_db" ]; then
        # Hash the file, insert meta data.
        hashed=($(md5sum "$dname""$fname"))
        md_hash=${hashed[0]}

        fcontent=$(hexdump -ve '1/1 "%.2x"' "$dname""$fname")
        sqlite3 "$DATABASE" "insert into file_path (cpath, cname) values('$dname', '$fname')"

        # Get the latest row.
        ROW=$(sqlite3 "$DATABASE" "select * from file_path order by fid desc limit 1")
        fid=$(echo "$ROW" | awk '{split($0,a,"|"); print a[1]}')

        #Insert file and hash data.
        fdate=$(stat -c %y "$dname""$fname")
        date_arr=("$fdate")
        echo -ne "\033[2K\r"
        echo -ne DB insert file: "$fid" - "$dname""$fname"\\r
        # Do pipe to avoid to long string for fcontent
        (echo -n "insert into file_content (content, hash, version, fdate, fid) values (X'$fcontent', '$md_hash', '1', '${date_arr[0]} ${date_arr[1]}', '$fid');") | sqlite3 "$DATABASE"
      fi
    fi
  fi
done
echo -ne "\033[2K"
echo Done, "$fid" files inserted in DB with mime type: \""$MIME_TYPE"\".
