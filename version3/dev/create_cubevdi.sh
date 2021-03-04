#!/bin/bash
#
env_path=/opt/opas/deploy/
export $(cat $env_path.env | xargs)

LOG=/var/log/batch_create.log

function create_cubevdi()
{
  # echo -e "Start create ise endpoint.." | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG

  _groupId=$1
  ise_endpoints=($(cat $RESULT_PATH/creating_$2_lists.txt$3))
  if [ ${#ise_endpoints[@]} -gt 500 ]; then
    echo -e "Please check compare list.. too much lists to create.." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEPC' ", $0; fflush() }' >> $LOG
  else
  for ((i = 0; i < ${#ise_endpoints[@]}; i++)); do
    # echo -e "Creating ise endpoint(${ise_endpoints[$i]}).." | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
    curl -s --insecure  \
        --include \
        --header 'Content-Type:application/json' \
        --header 'Accept: application/json' \
        --user $ISE_USER:$ISE_PASS \
        --request POST $ISE_PAN \
        --data '
          {
              "ERSEndPoint" : {
              "name" : "'${ise_endpoints[$i]}'",
              "description" : "",
              "mac" : "'${ise_endpoints[$i]}'",
              "groupId" : "'$_groupId'",
              "staticGroupAssignment" : true
              }
          }' |egrep "HTTP|title"  | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEVDI' Try creating endpoint('${ise_endpoints[$i]}') to ise('$CUBEVDI').. the result: ", $0; fflush() }'>> $LOG #|grep "title"  |awk -F" : " '{print  $2}' | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
  done
  fi
  if [ ${#ise_endpoints[@]} -eq 0 ]; then
    echo -e "There is no lists to create.." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEVDI' ", $0; fflush() }' >> $LOG
  fi
}

function rotate_log() {
  MAXLOG=5
  MAXSIZE=20480000
  log_name=/var/log/batch_create.log
  file_size=$(du -b $log_name | tr -s '\t' ' ' | cut -d' ' -f1)
  if [ $file_size -gt $MAXSIZE ]; then
    for i in $(seq $((MAXLOG - 1)) -1 1); do
      if [ -e $log_name"."$i ]; then
        mv $log_name"."{$i,$((i + 1))}
      fi
    done
    if [ ! -e $log_name ]; then
      touch $log_name
    fi
    mv $log_name $log_name".1"
    touch $log_name
  fi
}

# main
echo "=== ${0##*/} started ===" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
while true; do
  create_cubevdi $CUBEVDI_ID $CUBEVDI
  create_cubevdi $CUBEVDI_ID $CUBEVDI .1
  create_cubevdi $CUBEVDI_ID $CUBEVDI .2
  rotate_log
  sleep 1
done
