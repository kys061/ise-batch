#!/bin/bash
#
# 실제 배포시 변경할것 
# env_path=/opt/opas/deploy/
env_path=/home/saisei/dev/engineering/ise_batch/version3/dev/
export $(cat $env_path.env | xargs)
interval=60

LOG=/var/log/batch_update.log

function update_cubepc()
{
  # echo -e "Start create ise endpoint.." | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG

  _groupId=$1
  _webportal_mac=($(mysql $db_name -e "select mac_address from (select * from internal_assets_mac where not as_cls_cd = 1 or not as_ident_cd = 1 or not as_detail_cd = 5) as abc where is_login='Y' and login_time > DATE_FORMAT(DATE_ADD(now(),INTERVAL -$interval MINUTE), '%Y-%m-%d %H:%i:%s')" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
  
  if [ ${#_webportal_mac[@]} -gt 1000 ]; then
    echo -e "Please check.. too much lists to create.." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
  else
    if [ -f $RESULT_PATH/ise_others_endpoint_lists.txt ]; then
      ise_endpoints=($(cat $RESULT_PATH/ise_others_endpoint_lists.txt))
      for ((j = 0; j < ${#_webportal_mac[@]}; j++)); do
          webportal_mac_address=${_webportal_mac[$j]:0:2}":"${_webportal_mac[$j]:2:2}":"${_webportal_mac[$j]:4:2}":"${_webportal_mac[$j]:6:2}":"${_webportal_mac[$j]:8:2}":"${_webportal_mac[$j]:10:2}
          is_exist_in_ise=$(grep -i $webportal_mac_address $RESULT_PATH/ise_others_endpoint_lists.txt)
          if [ "$is_exist_in_ise" == "$webportal_mac_address" ]; then
            echo -e "Updating ise endpoint($webportal_mac_address).." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
            id=$(curl -s --insecure \
                      --header 'Accept: application/json' \
                      --user $ISE_USER:$ISE_PASS \
                      $ISE_PAN?filter=mac.EQ.$webportal_mac_address |$deploy_path/jq '.SearchResult.resources[].id?' |sed -e 's/"//g') 
            # echo -e "$webportal_mac_address" >> $RESULT_PATH/creating_$2_lists.txt.tmp
            curl -s --insecure  \
                  --include \
                  --header 'Content-Type:application/json' \
                  --header 'Accept: application/json' \
                  --user $ISE_USER:$ISE_PASS \
                  --request PUT $ISE_PAN/$id \
                  --data '
                        {
                          "ERSEndPoint" : {
                            "id" : "'$id'",
                            "name" : "'$webportal_mac_address'",
                            "description" : "",
                            "mac" : "'$webportal_mac_address'",
                            "profileId" : "",
                            "staticProfileAssignment" : false,
                            "groupId" : "'$_groupId'",   
                            "staticGroupAssignment" : true,
                            "portalUser" : "",
                            "identityStore" : "",
                            "identityStoreId" : "",
                            "link" : {
                              "rel" : "self",
                              "href" : "'$ISE_PAN'/'$id'",
                              "type" : "application/xml"
                            }
                          }
                        }'|egrep "HTTP|title" | awk '{ print strftime("%Y-%m-%d %T") " '$2' Try updating endpoint('$webportal_mac_address') to ise('$CUBEPC').. the result: ", $0; fflush() }' >> $LOG #|grep "title"  |awk -F" : " '{print  $2}' | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
            # is_exist_in_updating_lists=true
            sed -i 's/'$webportal_mac_address'//g' $RESULT_PATH/ise_others_endpoint_lists.txt
          else
            echo -e "There is no lists to update.." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
          fi
      done
      # cp $RESULT_PATH/creating_$2_lists.txt.tmp $RESULT_PATH/creating_$2_lists.txt
      # if [ "$is_exist_in_updating_lists" == "false" ]; then
      #   echo -e "There is no lists to write in updating lists.." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
      # fi
      # is_exist_in_updating_lists=false
      # echo -e "" |tr -d "\n" > $RESULT_PATH/creating_$2_lists.txt.tmp
    else
      echo -e "There is no ise_others_endpoint_lists.txt,, please check!!" | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
    fi
  fi
  if [ ${#_webportal_mac[@]} -eq 0 ]; then
    echo -e "There is no lists to update.." | awk '{ print strftime("%Y-%m-%d %T") " '$2' ", $0; fflush() }' >> $LOG
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
  update_cubepc $CUBEPC_ID $CUBEPC
  rotate_log
  sleep 1
done