#!/bin/bash
#
# 실제 배포시 변경할것 
# env_path=/opt/opas/deploy/
env_path=/home/saisei/dev/engineering/ise_batch/version3/dev/
export $(cat $env_path.env | xargs)
interval=60

LOG=/var/log/batch_create.log

function create_cubevdi()
{
  # echo -e "Start create ise endpoint.." | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG

  _groupId=$1
  _webportal_mac=($(mysql $db_name -e "select mac_address from internal_assets_mac where as_cls_cd = 1 and as_ident_cd = 1 and as_detail_cd = 5 and is_login = 'Y' and login_time > DATE_FORMAT(DATE_ADD(now(),INTERVAL -$interval MINUTE),'%Y-%m-%d %H:%i:%s')" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
  
  if [ ${#_webportal_mac[@]} -gt 1000 ]; then
    echo -e "Please check.. too much lists to create.." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
  else
    for ((i = 0; i < ${#_webportal_mac[@]}; i++)); do
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
                "name" : "'${_webportal_mac[$i]}'",
                "description" : "",
                "mac" : "'${_webportal_mac[$i]}'",
                "groupId" : "'$_groupId'",
                "staticGroupAssignment" : true
                }
            }' |egrep "HTTP|title" | awk '{ print strftime("%Y-%m-%d %T") " '$2' Try creating endpoint('${ise_endpoints[$i]}') to ise('$2').. the result: ", $0; fflush() }' >> $LOG #|grep "title"  |awk -F" : " '{print  $2}' | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
    done
  fi
  if [ ${#_webportal_mac[@]} -eq 0 ]; then
    echo -e "There is no lists to create.." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
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
  create_cubevdi $CUBEVDI_ID $CUBEVDI
  rotate_log
  sleep 1
done
