#!/bin/bash
#
LOG=/var/log/batch_start.log
# 실제 배포시 변경할것 
# deploy_path=/opt/opas/deploy/
deploy_path=/home/saisei/dev/engineering/ise_batch/version3/deploy/

lists=($(ls $deploy_path |egrep 'nogroups|update|create'))

function check_batch(){
    
    for ((j = 0; j < ${#lists[@]}; j++)); do
        ps_count=$(ps -ef |grep "${lists[$j]}" |grep -v grep |wc -l) 
        if [ $ps_count -eq 0 ]; then
            # cd deploy_path
            sudo $deploy_path${lists[$j]} &
            echo -e "Batch ${lists[$j]} is started.." | awk '{ print strftime("%Y-%m-%d %T") " start_batch ", $0; fflush() }' >> $LOG
        else
            echo -e "No need to start batch ${lists[$j]}" | awk '{ print strftime("%Y-%m-%d %T") " start_batch ", $0; fflush() }' >> $LOG
        fi
    done
}

# main
echo "=== ${0##*/} started ===" | awk '{ print strftime("%Y-%m-%d %T"), $0; fflush() }' >> $LOG
check_batch

# ./compare_cubepc_endpoint.sh & ./compare_cubemobile_endpoint.sh & ./compare_cubevdi_endpoint.sh &
# ./create_cubepc.sh & ./create_cubemobile.sh & ./create_cubevdi.sh &


#killall -9 create_cube*.sh
#killall -9 compare_cube*.sh

