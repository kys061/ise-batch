#!/bin/bash
#
# 실제 배포시 변경할것 
# env_path=/opt/opas/deploy/
env_path=/home/saisei/dev/engineering/version3/deploy/
export $(cat $env_path.env | xargs)

LOG=/var/log/batch_compare.log


is_exist_in_webportal=false
is_exist_in_ise=false
is_exist_in_creating_lists=false

function compare_cubepc_endpoint()
{
    _groupId=$1
    if [ "$3" == "internal" ]; then
      _webportal_mac=($(mysql $db_name -e "select mac_address from (select * from internal_assets_mac where not as_cls_cd = 1 or not as_ident_cd = 1 or not as_detail_cd = 5) as abc where is_login='Y'" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
    else
      _webportal_mac=($(mysql $db_name -e "select mac_address from external_assets_mac where asset_type = 'pc'" |egrep '^([[:xdigit:]]{2}[:.-]?){5}[[:xdigit:]]{2}$'))
    fi

    if [ -f $RESULT_PATH/ise_$2_endpoint_lists.txt ]; then
      ise_endpoints=($(cat $RESULT_PATH/ise_$2_endpoint_lists.txt))
      for ((j = 0; j < ${#_webportal_mac[@]}; j++)); do
          webportal_mac_address=${_webportal_mac[$j]:0:2}":"${_webportal_mac[$j]:2:2}":"${_webportal_mac[$j]:4:2}":"${_webportal_mac[$j]:6:2}":"${_webportal_mac[$j]:8:2}":"${_webportal_mac[$j]:10:2}
          is_exist_in_ise=$(grep -i $webportal_mac_address $RESULT_PATH/ise_$2_endpoint_lists.txt)
          if [ "$is_exist_in_ise" != "$webportal_mac_address" ]; then
            echo -e "Writing ise endpoint($webportal_mac_address).." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEPC' ", $0; fflush() }' >> $LOG
            echo -e "$webportal_mac_address" >> $RESULT_PATH/creating_$2_lists.txt.tmp
            is_exist_in_creating_lists=true
          fi
      done
      cp $RESULT_PATH/creating_$2_lists.txt.tmp $RESULT_PATH/creating_$2_lists.txt
      if [ "$is_exist_in_creating_lists" == "false" ]; then
        echo -e "There is no lists to write in creating lists.." | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEPC' ", $0; fflush() }' >> $LOG
      fi
      is_exist_in_creating_lists=false
      echo -e "" |tr -d "\n" > $RESULT_PATH/creating_$2_lists.txt.tmp
    else
      echo -e "There is no ise_$2_endpoint_lists.txt,, please check!!" | awk '{ print strftime("%Y-%m-%d %T") " '$CUBEPC' ", $0; fflush() }' >> $LOG
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
  if [ ! -e $log_name ]; then
    touch $log_name
  fi
  cp $log_name $log_name".1"
  # touch $log_name
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
  rotate_lists $RESULT_PATH/creating_${CUBEPC}_lists.txt
  compare_cubepc_endpoint $CUBEPC_ID $CUBEPC internal
#  compare_cubepc_endpoint $CUBEPC_ID $CUBEPC external
  rotate_log
done
