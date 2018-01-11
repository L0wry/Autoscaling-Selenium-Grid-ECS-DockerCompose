export CLUSTER_NAME=selenium-grid
export CLUSTER_SIZE=1
export SECURITY_GROUP='aws security group'
export VPC_ID='aws vpc'
export SUBNET_ID='aws vpc subnet id '
export AMI_ID='ami-7827b301' # aws ami for ECS instance 
export INSTANCE_TYPE='m4.large' 
export COMPOSEYML='docker-compose.yml'
export HUBCONTAINERNAME='hub'
export INSTANCESTOSCALETO=1  # ec2 Instances to scale too


# Clean up existing services: note will error if service does not exist
aws ecs update-service --cluster $CLUSTER_NAME --service "ecscompose-service-$CLUSTER_NAME" --desired-count 0
aws ecs delete-service --cluster $CLUSTER_NAME --service "ecscompose-service-$CLUSTER_NAME" &

ecs-cli configure --region eu-west-1 --cluster $CLUSTER_NAME 

# create ecs cluster of ec2 instances
ecs-cli up --capability-iam --size $CLUSTER_SIZE --security-group $SECURITY_GROUP --vpc $VPC_ID --subnets $SUBNET_ID --image-id $AMI_ID --instance-type $INSTANCE_TYPE --verbose --force

# create task definition for a docker container
ecs-cli compose --file $COMPOSEYML --project-name $CLUSTER_NAME --verbose create

# create elb & add a dns CNAME for the elb dns
aws elb create-load-balancer --load-balancer-name "$CLUSTER_NAME" --listeners Protocol="TCP,LoadBalancerPort=4444,InstanceProtocol=TCP,InstancePort=4444" --subnets "$SUBNET_ID" --security-groups "$SECURITY_GROUP" --scheme internet-facing 

# get auto Scaling Group name
export AUTOSCALINGGROUPNAME=$(aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[] | select (.AutoScalingGroupName | contains ("amazon-ecs-cli-setup-selenium")) | .AutoScalingGroupName' | tr -d "\"") 

# Scale up and down grid EC2 instances monday to friday 
aws autoscaling put-scheduled-update-group-action --auto-scaling-group-name $AUTOSCALINGGROUPNAME --scheduled-action-name scale-up --recurrence "2 08-8 * * MON-FRI" --min-size $INSTANCESTOSCALETO --max-size $INSTANCESTOSCALETO --desired-capacity $INSTANCESTOSCALETO 
aws autoscaling put-scheduled-update-group-action --auto-scaling-group-name $AUTOSCALINGGROUPNAME --scheduled-action-name scale-down --recurrence "1 8-08 * * MON-FRI" --min-size 0 --max-size 0 --desired-capacity 0 

# create service with above created task definition & elb
aws ecs create-service --service-name "ecscompose-service-$CLUSTER_NAME" --cluster "$CLUSTER_NAME" --task-definition "$CLUSTER_NAME" --load-balancers "loadBalancerName=$CLUSTER_NAME,containerName=$HUBCONTAINERNAME,containerPort=4444" --desired-count 1 --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50" --role ecsServiceRole

# export hosted name  ID 
export HOSTEDZONENAMEID=$(aws elb describe-load-balancers | jq ".LoadBalancerDescriptions[] | select (.LoadBalancerName  == \"$CLUSTER_NAME\") | .CanonicalHostedZoneNameID" | tr -d "\"")
export ELBDNS=$(aws elb describe-load-balancers | jq ".LoadBalancerDescriptions[] | select (.LoadBalancerName  == \"$CLUSTER_NAME\") | .DNSName" | tr -d "\"")

# Update hosted Zone with hoseted name ID + ELB DNS
node updateHostedZone.js 

#Set selenium endpoint in route 53 to point to new elb  
aws route53 change-resource-record-sets --hosted-zone-id Z18Q0FIQJPNVNK --change-batch file://hosted-zone.json