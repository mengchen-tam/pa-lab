# AWS AutoScaling of the Palo Alto Firewall VMs in the Centralized Egress Inpsection VPC

# Overview

The terraform code in this pattern provisions an Egress Inspection VPC in AWS using the Gateway Load Balancer and the Autoscaling of the VM-Series Palo Alto Firewall instances as shown in the architecture diagram.

The Autoscaling group is configured with dynamic scaling policies using the CloudWatch metrics sent by the Palo Alto VMs.

Two dynamic scaling policies 1.panSessionUtilization and 2. DataPlaneCPUUtilizationPct are configured on ASG. ASG actively monitors these alarms and scale-out and scale based on the thresholds defined in the configuration. 

During a scale-out event, ASG launches an instance using the AWS launch template configuration with a data network interface (data-eni) on device index 0.

A lifecycle hook (“launch“) triggers the Lambda function that creates and attaches a management network interface (mgmt-eni) on device index 1 on the Palo Alto EC2 instance. 

The Palo Alto VM bootstraps using the configuration provided in the UserData from the AWS launch template configuration.

During a scale-in event, the ASG lifecycle hook (“terminate“) triggers the lambda function that will detach and delete the management interface and send complete lifecycle action back to the ASG to remove the instances from the group successfully.

The terraform code also provisions a spoke vpc, tgw attachments, and required route tables to route all of the egress traffic from the ec2 instance in the private subnet of the spoke vpc to the internet through inspection VPC Palo Alto firewalls.

To make the process easier, the code also deploys SSM endpoints to connect to the ec2 instance in the spoke vpc using SSM.

`Note: The purpose of this post is to demonstrate the AWS Autoscaling of the Palo Alto VM-Series firewalls with Dynamic Scaling Policies in the egress inspection vpc. Users should refer to the Palo Alto documentation while configuring resources per their recommendations and best practices.`

# Architecture

![](./pa_asg_gwlb.png)

## Pre Requisites

1. Generate a EC2 key pair, if you do not have one available to use.

## Deployment Steps

1. terraform init
2. terraform apply
3. Input the EC2 Key Name and Palo Alto AMI ID 

## Troubleshooting 

If the Palo Alto Market Place AMI is not subscribed, Terraform apply fails with similar error message as shown below. To fix the error, you should subscribe to the market place AMI by using the URL provided in the error message.

```
│ Error: creating Auto Scaling Group (myasg): ValidationError: You must use a valid fully-formed launch template. In order to use this AWS Marketplace product you need to accept terms and subscribe. To do so please visit https://aws.amazon.com/marketplace/pp?sku=xxx
│ 	status code: 400, request id: 467395b0-325d-4127-a42b-8351cc7b8bce
│ 
│   with module.ec2_vpc.aws_autoscaling_group.myasg,
│   on modules/aws_ec2_vpc/asg.tf line 59, in resource "aws_autoscaling_group" "myasg":
│   59: resource "aws_autoscaling_group" "myasg" {
```
## Post Deployment Steps (Mandatory):

`Note: Wait atleast 20-25 mins for the Palo Alto VMs to bootstrap.`

## 1. Assign EIP to the Management Interface of the Palo Alto VMs.

 To access the Palo Alto VMs via SSH and Web Browser, assign an elastic IP on to the PAVM Management Network Interface.

## 2. Assign Admin user password to access the Palo Alto VMs.

```
ssh -i <KEY_NAME>.pem  admin@<EIP>

admin@vmseries-fw1-poc> configure
Entering configuration mode
[edit]                                                                                                                                                                                                                                       
admin@vmseries-fw1-poc# set mgt-config users admin password
Enter password   : 
Confirm password : 

[edit]                                                                                                                                                                                                                                       
admin@vmseries-fw1-poc# commit

Commit job 3 is in progress. Use Ctrl+C to return to command prompt
..............55%.98%................100%
Configuration committed successfully

[edit]                                                                                                                                                                                                                                       
admin@vmseries-fw1-poc# exit
Exiting configuration mode
admin@vmseries-fw1-poc> exit
Connection to xxx closed.
```

## 3. Configure a Management and Security Profile

Complete `Step-6` and `Step-7` from the below article to Configure a Management profile allowing “https” for GWLB Target Group Health Checks to pass and security profile allowing traffic. 

 https://docs.paloaltonetworks.com/vm-series/10-1/vm-series-deployment/set-up-the-vm-series-firewall-on-aws/vm-series-integration-with-gateway-load-balancer/integrate-the-vm-series-with-an-aws-gateway-load-balancer/manually-integrate-the-vm-series-with-a-gateway-load-balancer.  


![](./pavm_gwlb_https_health_check_profile.png)

![](./gwlb-hhtps-health-check-profile.png)

Commit the changes and you should see the GWLB target group health checks passing and the traffic from the GWLB health checks under the Monitor section of the firewalls.

## 4. Enable CloudWatch Metrics 

Follow the `Step-2` to enable cloud watch metrics on the Palo Alto VMs.

https://docs.paloaltonetworks.com/vm-series/9-1/vm-series-deployment/set-up-the-vm-series-firewall-on-aws/deploy-the-vm-series-firewall-on-aws/enable-cloudwatch-monitoring-on-the-vm-series-firewall

Commit changes in the Firewalls, and a custom namespace will be created with the Palo Alto VM metrics like below:

![](./cw_metrics.png)

## Verify

After successfull deployment, completing the pre requisites, post deployment steps and making sure the GWLB target group health checks are passing, login to the AWS console and connect to anyone of the EC2 spoke-vm (spoke_vpc_vm_az1/2) via SSM manager and execute curl "https://google.com/", and you should see the traffic is routed to the Palo Alto instances.

![](./pavm_traffic_monitoring.png)
