#!/bin/bash

export CLUSTER_NAME=hosted-selenium-grid
export CLUSTER_SIZE=1
export SECURITY_GROUP='sg-'
export VPC_ID='vpc-'
export PUBLIC_SUBNET_ID='subnet-'
export AMI_ID='ami-7827b301'
export INSTANCE_TYPE='c5.2xlarge'
export COMPOSEYML='docker-compose.yml'
export HUBCONTAINERNAME='hub'
export ELASTICIP=''

# Clean up existing services: note will error if service does not exist
aws ecs update-service --cluster $CLUSTER_NAME --service "ecscompose-service-$CLUSTER_NAME" --desired-count 0
aws ecs delete-service --cluster $CLUSTER_NAME --service "ecscompose-service-$CLUSTER_NAME" &

ecs-cli configure --region eu-west-1 --cluster $CLUSTER_NAME 

# create ecs cluster of ec2 instances
ecs-cli up --capability-iam --size $CLUSTER_SIZE --security-group $SECURITY_GROUP --vpc $VPC_ID --subnets $PUBLIC_SUBNET_ID --image-id $AMI_ID --instance-type $INSTANCE_TYPE  --keypair TNLDefault --verbose --force

# create log groups for cloud watch
aws logs create-log-group --log-group-name selenium-hub --region eu-west-1
aws logs create-log-group --log-group-name selenium-node --region eu-west-1

# create task definition for a docker container
ecs-cli compose --file $COMPOSEYML --project-name $CLUSTER_NAME --verbose create

#create load balencer to keep create-service happy
aws elb create-load-balancer --load-balancer-name "$CLUSTER_NAME" --listeners Protocol="TCP,LoadBalancerPort=4444,InstanceProtocol=TCP,InstancePort=4444" --subnets "$PUBLIC_SUBNET_ID" --security-groups "$SECURITY_GROUP" --scheme internet-facing 

sleep 15

# get the new instance id
export MATCHING_INSTANCES=$(aws ec2 describe-instances --filters="Name=subnet-id,Values=\"$PUBLIC_SUBNET_ID\",Name=instance-type,Values=\"$INSTANCE_TYPE\"")
export INSTANCEID=$(echo $MATCHING_INSTANCES | jq '.Reservations[].Instances[] | select(.State.Name!="terminated") | .InstanceId' | tr -d "\"");

# Set Elastic IP to new ec2 instance
aws ec2 associate-address --instance-id $INSTANCEID --public-ip $ELASTICIP

aws elb register-instances-with-load-balancer --load-balancer-name $CLUSTER_NAME --instances $INSTANCEID

# get auto Scaling Group name
export AUTOSCALINGGROUPNAME=$(aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[] | select (.AutoScalingGroupName | contains ("amazon-ecs-cli-")) | .AutoScalingGroupName' | tr -d "\"") 

# Scale up and down grid EC2 instances monday to friday 
aws autoscaling put-scheduled-update-group-action --auto-scaling-group-name $AUTOSCALINGGROUPNAME --start-time $(date -v +2H "+%Y-%m-%dT%H:%M:%S") --scheduled-action-name scale-down --recurrence "1 8-08 * * MON-FRI" --min-size 0 --max-size 0 --desired-capacity 0 

# create service with above created task definition & elb
aws ecs create-service --service-name "ecscompose-service-$CLUSTER_NAME" --cluster "$CLUSTER_NAME" --task-definition "$CLUSTER_NAME" --load-balancers "loadBalancerName=$CLUSTER_NAME,containerName=$HUBCONTAINERNAME,containerPort=4444" --desired-count 1 --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50" --role ecsServiceRole
