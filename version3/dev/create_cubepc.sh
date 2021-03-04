#!/bin/bash
#
env_path=/opt/opas/deploy/
export $(cat $env_path.env | xargs)

LOG=/var/log/batch_create.log

function create_cubepc()
{
  # echo -e "Start create ise endpoint.." | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG

  _groupId=$1
  ise_endpoints=($(cat $RESULT_PATH/creating_$2_lists.txt$3))
  if [ "$3" == "internal" ]; then
    _webportal_mac=($(mysql $db_name -e "select mac_address from (select * from internal_assets_mac where not as_cls_cd = 1 or not as_ident_cd = 1 or not as_detail_cd = 5) as abc where is_login='Y'" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
  else
    _webportal_mac=($(mysql $db_name -e "select mac_address from external_assets_mac where asset_type = 'pc'" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
  fi
  
  if [ ${#ise_endpoints[@]} -gt 1000 ]; then
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
            }' |egrep "HTTP|title" | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEPC' Try creating endpoint('${ise_endpoints[$i]}') to ise('$CUBEPC').. the result: ", $0; fflush() }' >> $LOG #|grep "title"  |awk -F" : " '{print  $2}' | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
    done
  fi
  if [ ${#ise_endpoints[@]} -eq 0 ]; then
    echo -e "There is no lists to create.." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEPC' ", $0; fflush() }' >> $LOG
  fi
  # echo -e "End create ise endpoint" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
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
  create_cubepc $CUBEPC_ID $CUBEPC
  create_cubepc $CUBEPC_ID $CUBEPC .1
  create_cubepc $CUBEPC_ID $CUBEPC .2
  rotate_log
  sleep 1
done
