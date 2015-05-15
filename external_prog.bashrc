#!/bin/bash

# params=($line)
# Arguments passed to this script:
# $1 -> date
# $2 -> time
# $3 -> dir
# $4 -> event / filename  -+
# $5 -> event             -+
#                          +-> If $5 is not set then it is a DIR,
#                              otherwise $4 contains the file name.

SCRIPT_DIR=$(echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")
DATABASE="$SCRIPT_DIR"/monitored_files.sqlite

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

# Do we have a file or a directory?
if [ ! -z "$5" ]; then
  # Now we have a file, check if it is in db.
  # Be sure to get the latest version.
  db_data=$(sqlite3 "$DATABASE" "SELECT file_path.fid, hash, version FROM file_path, file_content WHERE cpath like '$3' AND cname LIKE '$4' AND file_path.fid = file_content.fid ORDER BY fcid DESC LIMIT 1")

  # If file in DB
  if [ ! -z "$db_data" ]; then
    # Split fields on |
    db_fid=$(echo $db_data | awk '{split($0,a,"|"); print a[1]}')
    db_hash=$(echo $db_data | awk '{split($0,a,"|"); print a[2]}')
    db_version=$(echo $db_data | awk '{split($0,a,"|"); print a[3]}')

    hashed=$(md5sum $3$4)
    md_hash=(${hashed[0]})

    # Are there any changes to the file?
    if [ ! "$md_hash" == "$db_hash" ]; then
      # Yes, there is changes to the file.
      # Now we need to insert a new version.
      fcontent=$(hexdump -ve '1/1 "%.2x"' $3$4)
      version=$((db_version+1))
      fdate=$(stat -c %y $3$4)
      date_arr=($fdate)

      # Do pipe to avoid to long string for fcontent
      (echo -n "insert into file_content (content, hash, version, fdate, fid) values (X'$fcontent', '$md_hash', '$version', '${date_arr[0]} ${date_arr[1]}', '$db_fid');") | sqlite3 "$DATABASE"

      # Log into syslog.
      logger EXTERNAL_PROG: file $3$4 has changed: "$fdate"

      # Now it is time to see if there is a plugin for this file.
      if [ -e $SCRIPT_DIR/plugins/$4 ]; then
        logger inotify_plugin: $4 $1 $2 $3 $4 $5
        $SCRIPT_DIR/plugins/$4 $1 $2 $3 $4 $5
      fi
      if [ -e $SCRIPT_DIR/plugins/$4.bashrc ]; then
        logger inotify_plugin: $4.bashrc $1 $2 $3 $4 $5
        $SCRIPT_DIR/plugins/$4.bashrc $1 $2 $3 $4 $5
      fi
    fi
#  else
#   here we should add some stuff to insert a created file.
  fi
fi
