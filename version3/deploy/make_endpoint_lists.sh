#!/bin/bash
#
# 실제 배포시 변경할것 
# env_path=/opt/opas/deploy/
env_path=/home/saisei/dev/engineering/ise_batch/version3/dev/
export $(cat $env_path.env | xargs)

LOG=/var/log/batch_make.log

is_exist_in_webportal=false
is_exist_in_ise=false

nogroupId=aa0e8b20-8bff-11e6-996c-525400b48521

function make_endpoint_list(){
    echo "start make_endpoint_list" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
    _CUBEPC_ID=$1
    _CUBEMOBILE_ID=$2
    _CUBEVDI_ID=$3

    _total_count=$(curl -s --insecure \
        --header  'Accept: application/json' \
        --user $ISE_USER:$ISE_PASS \
        $ISE_PAN |$deploy_path/jq '.SearchResult.total?')

    _total_pages=`expr $_total_count / 20 + 1`
    if [ ! -d $RESULT_PATH ]; then
        mkdir $RESULT_PATH
    fi
    echo "" |tr -d "\n" > $RESULT_PATH/ise_$4_endpoint_lists.txt.tmp
    echo "" |tr -d "\n" > $RESULT_PATH/ise_$5_endpoint_lists.txt.tmp
    echo "" |tr -d "\n" > $RESULT_PATH/ise_$6_endpoint_lists.txt.tmp
    echo "" |tr -d "\n" > $RESULT_PATH/ise_others_endpoint_lists.txt.tmp
    # echo "debug01-$_total_count-$_total_pages-$RESULT_PATH-$ISE_USER-$ISE_PASS" >> $LOG
    # for ((k = 1; k <= $_total_pages; k++)); do
    for ((k = $_total_pages; k >= 1; k--)); do
        echo "Making endpoints $k/$_total_pages.." | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
        ise_endpoint_all_id=($(curl -s --insecure \
                                        --header  'Accept: application/json' \
                                        --user $ISE_USER:$ISE_PASS \
                                        $ISE_PAN?page=$k |grep "id" |egrep '[a-zA-Z0-9-]{36}' -o))
        ise_endpoint_all_mac=($(curl -s --insecure \
                                        --header  'Accept: application/json' \
                                        --user $ISE_USER:$ISE_PASS \
                                        $ISE_PAN?page=$k |egrep '[a-zA-Z0-9:]{17}' -o))
        for ((i = 0; i < ${#ise_endpoint_all_id[@]}; i++)); do
            ise_endpoint_groupid=$(curl -s --insecure \
                    --header 'Accept: application/json' \
                    --user $ISE_USER:$ISE_PASS \
                    $ISE_PAN/${ise_endpoint_all_id[$i]} |$deploy_path/jq '.ERSEndPoint.groupId?' |sed -e 's/"//g') 
            if [ "$ise_endpoint_groupid" == "$_CUBEPC_ID" ]; then
              break
              echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_$4_endpoint_lists.txt.tmp
            elif [ "$ise_endpoint_groupid" == "$_CUBEMOBILE_ID" ]; then
              break
              echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_$5_endpoint_lists.txt.tmp
            elif [ "$ise_endpoint_groupid" == "$_CUBEVDI_ID" ]; then
              break
              echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_$6_endpoint_lists.txt.tmp
            else
              echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_others_endpoint_lists.txt.tmp
            fi

            # if [ "$ise_endpoint_groupid" == "$_CUBEMOBILE_ID" ]; then
            #     echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_$5_endpoint_lists.txt.tmp
            # fi
            # if [ "$ise_endpoint_groupid" == "$_CUBEVDI_ID" ]; then
            #     echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_$6_endpoint_lists.txt.tmp
            # else
            #     echo ${ise_endpoint_all_mac[$i]} | tr '[A-Z]' '[a-z]' >> $RESULT_PATH/ise_others_endpoint_lists.txt.tmp
            # fi
        done  
    done
    cp $RESULT_PATH/ise_$4_endpoint_lists.txt.tmp $RESULT_PATH/ise_$4_endpoint_lists.txt
    cp $RESULT_PATH/ise_$5_endpoint_lists.txt.tmp $RESULT_PATH/ise_$5_endpoint_lists.txt
    cp $RESULT_PATH/ise_$6_endpoint_lists.txt.tmp $RESULT_PATH/ise_$6_endpoint_lists.txt
    cp $RESULT_PATH/ise_others_endpoint_lists.txt.tmp $RESULT_PATH/ise_others_endpoint_lists.txt
    echo "end make_endpoint_list" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
}

function rotate_log() {
  MAXLOG=5
  MAXSIZE=20480000
  log_name=/var/log/batch_make.log
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

function rotate_lists() {
  MAXLOG=5
  log_name=$1
  if [ ! -d $RESULT_PATH ]; then
    mkdir $RESULT_PATH
  fi
  for i in $(seq $((MAXLOG - 1)) -1 1); do
    if [ -e $log_name"."$i ]; then
      cp $log_name"."{$i,$((i + 1))}
    fi
  done
  if [ ! -e $log_name ]; then
    touch $log_name
  fi
  cp $log_name $log_name".1"
  # touch $log_name
}

# main
echo "=== ${0##*/} started ===" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
while true; do
  rotate_lists $RESULT_PATH/ise_${CUBEPC}_endpoint_lists.txt
  sleep 1
  rotate_lists $RESULT_PATH/ise_${CUBEMOBILE}_endpoint_lists.txt
  sleep 1
  rotate_lists $RESULT_PATH/ise_${CUBEVDI}_endpoint_lists.txt
  sleep 1
  rotate_lists $RESULT_PATH/ise_others_endpoint_lists.txt
  sleep 1
  make_endpoint_list $CUBEPC_ID $CUBEMOBILE_ID $CUBEVDI_ID $CUBEPC $CUBEMOBILE $CUBEVDI
  sleep 1
  rotate_log
done