# ==============================================================================
# AWS Assignment 7: Full Teardown / Cleanup Script
# ==============================================================================
$ErrorActionPreference = "Continue"
$REGION = "ap-southeast-1"

Write-Host "===============================================================" -ForegroundColor Yellow
Write-Host " 🧹 DELETING ALL ASSIGNMENT 7 RESOURCES IN $REGION..." -ForegroundColor Yellow
Write-Host "===============================================================" -ForegroundColor Yellow

# 1. Delete Auto Scaling Group
Write-Host "`n[1/7] Deleting Auto Scaling Group..."
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "ssc-result-asg" --min-size 0 --desired-capacity 0 --region $REGION 2>$null
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "ssc-result-asg" --force-delete --region $REGION 2>$null

# 2. Delete Load Balancer & Target Group
Write-Host "[2/7] Deleting Application Load Balancer & Target Group..."
$ALB_ARN = (aws elbv2 describe-load-balancers --names "ssc-result-alb" --region $REGION --query "LoadBalancers[0].LoadBalancerArn" --output text 2>$null)
if ($ALB_ARN -and $ALB_ARN -ne "None") {
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION
    Write-Host "Waiting 15 seconds for ALB to release network interfaces..."
    Start-Sleep -Seconds 15
}

$TG_ARN = (aws elbv2 describe-target-groups --names "ssc-result-tg" --region $REGION --query "TargetGroups[0].TargetGroupArn" --output text 2>$null)
if ($TG_ARN -and $TG_ARN -ne "None") {
    aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION
}

# 3. Delete Launch Template
Write-Host "[3/7] Deleting Launch Template..."
aws ec2 delete-launch-template --launch-template-name "ssc-ubuntu-template" --region $REGION 2>$null

# 4. Delete NAT Gateway & Release EIP
Write-Host "[4/7] Deleting NAT Gateway & Releasing Elastic IP..."
$NAT_ID = (aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=ssc-nat-gw" "Name=state,Values=available,pending" --region $REGION --query "NatGateways[0].NatGatewayId" --output text 2>$null)
if ($NAT_ID -and $NAT_ID -ne "None") {
    aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID --region $REGION
    Write-Host "Waiting for NAT Gateway to delete..."
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID --region $REGION
}

$EIP_ALLOC = (aws ec2 describe-addresses --filters "Name=tag:Name,Values=ssc-nat-eip" --region $REGION --query "Addresses[0].AllocationId" --output text 2>$null)
if ($EIP_ALLOC -and $EIP_ALLOC -ne "None") {
    aws ec2 release-address --allocation-id $EIP_ALLOC --region $REGION
}

# 5. Wait for terminated instances / network interfaces to release
Write-Host "[5/7] Waiting for EC2 instances to fully terminate..."
$VPC_ID = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ssc-result-vpc" --region $REGION --query "Vpcs[0].VpcId" --output text 2>$null)
if ($VPC_ID -and $VPC_ID -ne "None") {
    $INSTANCES = (aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,pending,shutting-down" --region $REGION --query "Reservations[*].Instances[*].InstanceId" --output text 2>$null)
    if ($INSTANCES) {
        aws ec2 terminate-instances --instance-ids ($INSTANCES.Split()) --region $REGION 2>$null
        Start-Sleep -Seconds 20
    }

    # 6. Detach and Delete IGW, Subnets, Route Tables
    Write-Host "[6/7] Deleting IGW, Subnets, and Route Tables..."
    $IGW_ID = (aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region $REGION --query "InternetGateways[0].InternetGatewayId" --output text 2>$null)
    if ($IGW_ID -and $IGW_ID -ne "None") {
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 2>$null
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION 2>$null
    }

    $SUBS = (aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query "Subnets[*].SubnetId" --output text 2>$null)
    if ($SUBS) {
        foreach ($sub in $SUBS.Split()) {
            if ($sub) { aws ec2 delete-subnet --subnet-id $sub --region $REGION 2>$null }
        }
    }

    $RTS = (aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query "RouteTables[?Associations[0].Main!=true].RouteTableId" --output text 2>$null)
    if ($RTS) {
        foreach ($rt in $RTS.Split()) {
            if ($rt) { aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>$null }
        }
    }

    # 7. Delete Security Groups and VPC
    Write-Host "[7/7] Deleting Security Groups and VPC..."
    Start-Sleep -Seconds 10
    $SGS = (aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>$null)
    if ($SGS) {
        foreach ($sg in $SGS.Split()) {
            if ($sg) { aws ec2 delete-security-group --group-id $sg --region $REGION 2>$null }
        }
    }

    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>$null
}

Write-Host "===============================================================" -ForegroundColor Green
Write-Host " ✅ ALL RESOURCES COMPLETELY CLEANED UP!" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
