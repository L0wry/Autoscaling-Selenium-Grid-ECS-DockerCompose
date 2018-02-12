
export CLUSTER_NAME=hosted-selenium-grid

export TASKARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME | jq -r ".taskArns[]")
export TASKID=$(echo $TASKARN | grep -o '/.*'  | cut -f2- -d/)
aws ecs stop-task --cluster $CLUSTER_NAME --task $TASKID