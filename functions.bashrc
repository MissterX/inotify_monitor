#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
WHITE=$(tput setaf 7)
TERM_WIDTH=$(tput cols)
TXT_FAILED='[FAIL]'
TXT_OK='[ OK ]'

function print_mess() {
  MESS=$2
  HOR_COL=$(($TERM_WIDTH - ${#MESS} - 3))
  if [ $1 == "OK" ]; then
    COL=$GREEN
    TXT=$TXT_OK
  else
    COL=$RED
    TXT=$TXT_FAILED
  fi
  printf "$2%*s%s%s%s\n" $HOR_COL $COL "$TXT" $WHITE
}
