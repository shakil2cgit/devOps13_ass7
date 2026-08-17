$ErrorActionPreference = "Continue"
$REGION = "ap-southeast-1"
$AMI_ID = "ami-06afb763249172368"
$EC2_SG = "sg-0f3cd0d2d71ce4f07"
$PRIV_SUB_1 = "subnet-004c483beed3475c3"
$PRIV_SUB_2 = "subnet-0af48eef2142ab599"

Write-Host "Fetching Target Group ARN..."
$TG_ARN = (aws elbv2 describe-target-groups --names "ssc-result-tg" --region $REGION --query "TargetGroups[0].TargetGroupArn" --output text)

Write-Host "Creating Launch Template (Ubuntu 22.04, t3.micro)..."
$USER_DATA_PATH = Join-Path $PSScriptRoot "user-data.sh"
$USER_DATA_BASE64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($USER_DATA_PATH))

$LT_DATA = @"
{
  "ImageId": "$AMI_ID",
  "InstanceType": "t3.micro",
  "SecurityGroupIds": ["$EC2_SG"],
  "UserData": "$USER_DATA_BASE64",
  "MetadataOptions": {
    "HttpEndpoint": "enabled",
    "HttpTokens": "required",
    "HttpPutResponseHopLimit": 2
  },
  "TagSpecifications": [
    {
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "ssc-result-ubuntu-node"}
      ]
    }
  ]
}
"@

$LT_FILE = Join-Path $PSScriptRoot "lt_config.json"
Set-Content -Path $LT_FILE -Value $LT_DATA

# Delete old launch template if exists
aws ec2 delete-launch-template --launch-template-name "ssc-ubuntu-template" --region $REGION 2>$null

$LT_ID = (aws ec2 create-launch-template --launch-template-name "ssc-ubuntu-template" --version-description "v1" --launch-template-data file://$LT_FILE --region $REGION --query "LaunchTemplate.LaunchTemplateId" --output text)
Remove-Item $LT_FILE -Force
Write-Host "✅ Launch Template Created: $LT_ID" -ForegroundColor Green

Write-Host "Creating Auto Scaling Group in Private Subnets ($PRIV_SUB_1, $PRIV_SUB_2)..."
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "ssc-result-asg" --force-delete --region $REGION 2>$null

aws autoscaling create-auto-scaling-group `
  --auto-scaling-group-name "ssc-result-asg" `
  --launch-template "LaunchTemplateId=$LT_ID,Version=`$Latest" `
  --min-size 2 `
  --max-size 10 `
  --desired-capacity 2 `
  --target-group-arns $TG_ARN `
  --vpc-zone-identifier "$PRIV_SUB_1,$PRIV_SUB_2" `
  --health-check-type ELB `
  --health-check-grace-period 180 `
  --tags "Key=Name,Value=ssc-result-worker,PropagateAtLaunch=true" `
  --region $REGION

Write-Host "Configuring CPU Target Tracking Scaling Policy (50%)..."
$POLICY_FILE = Join-Path $PSScriptRoot "policy.json"
Set-Content -Path $POLICY_FILE -Value '{"PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},"TargetValue":50.0}'

aws autoscaling put-scaling-policy `
  --auto-scaling-group-name "ssc-result-asg" `
  --policy-name "ssc-cpu-target-tracking-50" `
  --policy-type TargetTrackingScaling `
  --target-tracking-configuration file://$POLICY_FILE `
  --region $REGION | Out-Null
Remove-Item $POLICY_FILE -Force

Write-Host "===============================================================" -ForegroundColor Green
Write-Host " 🎉 ALL AWS RESOURCES DEPLOYED AND LIVE!" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host " 🌐 Website URL (ALB DNS): http://ssc-result-alb-940391316.ap-southeast-1.elb.amazonaws.com" -ForegroundColor Cyan
Write-Host " 📍 Launch Template: $LT_ID" -ForegroundColor Cyan
Write-Host " 📍 Auto Scaling Group: ssc-result-asg (Min: 2, Desired: 2, Max: 10)" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Green
