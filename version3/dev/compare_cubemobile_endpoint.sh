#!/bin/bash
#
#env_path=/opt/opas/deploy/
env_path=/home/saisei/dev/engineering/version3/deploy/
export $(cat $env_path.env | xargs)

LOG=/var/log/batch_compare.log

is_exist_in_webportal=false
is_exist_in_ise=false
is_exist_in_creating_lists=false

function compare_cubemobile_endpoint()
{
    echo -e "" |tr -d "\n" > $RESULT_PATH/creating_$2_lists.txt.tmp
    _groupId=$1
    webportal_mac=($(mysql $db_name -e "select mac_address from mobile_mac where is_login='Y'" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
    if [ -f $RESULT_PATH/ise_$2_endpoint_lists.txt ]; then
      for ((j = 0; j < ${#webportal_mac[@]}; j++)); do
          webportal_mac_address=${webportal_mac[$j]:0:2}":"${webportal_mac[$j]:2:2}":"${webportal_mac[$j]:4:2}":"${webportal_mac[$j]:6:2}":"${webportal_mac[$j]:8:2}":"${webportal_mac[$j]:10:2}
          is_exist_in_ise=$(grep -i $webportal_mac_address $RESULT_PATH/ise_$2_endpoint_lists.txt)
          if [ "$is_exist_in_ise" != "$webportal_mac_address" ]; then
            echo -e "Writing ise endpoint($webportal_mac_address).." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEMOBILE' ", $0; fflush() }' >> $LOG
            echo -e "$webportal_mac_address" >> $RESULT_PATH/creating_$2_lists.txt.tmp
            is_exist_in_creating_lists=true      
          fi
      done
      cp $RESULT_PATH/creating_$2_lists.txt.tmp $RESULT_PATH/creating_$2_lists.txt
      if [ "$is_exist_in_creating_lists" == "false" ]; then
        echo -e "There is no lists to write in creating lists.." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEMOBILE' ", $0; fflush() }' >> $LOG
      fi
      is_exist_in_creating_lists=false
    else
      echo -e "There is no ise_$2_endpoint_lists.txt,, please check!!" | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEMOBILE' ", $0; fflush() }' >> $LOG
    fi
}

function rotate_lists() {
  MAXLOG=5
  log_name=$1
  for i in $(seq $((MAXLOG - 1)) -1 1); do
    if [ -e $log_name"."$i ]; then
      cp $log_name"."{$i,$((i + 1))}
    fi
  done
  cp $log_name $log_name".1"
  #touch $log_name
}

function rotate_log() {
  MAXLOG=5
  MAXSIZE=20480000
  log_name=/var/log/batch_compare.log
  file_size=$(du -b $log_name | tr -s '\t' ' ' | cut -d' ' -f1)
  if [ $file_size -gt $MAXSIZE ]; then
    for i in $(seq $((MAXLOG - 1)) -1 1); do
      if [ -e $log_name"."$i ]; then
        mv $log_name"."{$i,$((i + 1))}
      fi
    done
    mv $log_name $log_name".1"
    touch $log_name
  fi
}

# main
echo "=== ${0##*/} started ===" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
while true; do
  rotate_lists $RESULT_PATH/creating_${CUBEMOBILE}_lists.txt
  sleep 1
  compare_cubemobile_endpoint $CUBEMOBILE_ID $CUBEMOBILE
  rotate_log
  sleep 5
done
