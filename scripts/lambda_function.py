import boto3
import logging
import time
from botocore.exceptions import ClientError
import os
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)

env_vars = {}

env_vars.update({
    'mgmt_sg':str(os.environ['mgmt_sg']),
    'mgmt_subnet_az1': str(os.environ['mgmt_subnet_az1']),
    'mgmt_subnet_az2': str(os.environ['mgmt_subnet_az2']),
})

try:

    autoscaling = boto3.client('autoscaling')
    ec2 = boto3.client('ec2')
    ec2_rsr = boto3.resource('ec2')


except ClientError as e:

    message = 'ERROR CONNECTING TO CLIENT: {}'.format(e)
    logger.error(message)

    raise Exception(message)

def send_lifecycle_action(event, result):

    try:

        response = autoscaling.complete_lifecycle_action(
            LifecycleHookName=event['detail']['LifecycleHookName'],
            AutoScalingGroupName=event['detail']['AutoScalingGroupName'],
            LifecycleActionToken=event['detail']['LifecycleActionToken'],
            LifecycleActionResult=result,
            InstanceId=event['detail']['EC2InstanceId']
        )

        logger.info(response)

        return "SUCCESS"

    except ClientError as e:

        message = 'ERROR SENDING LIFECYCLE ACTION EVENT TO ASG. MESSAGE:- {}'.format(e)
    
        logger.error(message)
        raise Exception(message)


def remove_interfaces(event):
    logger.info('REMOVE NETWORK INTERFACES ON EC2: {}'.format(event['detail']['EC2InstanceId']))
    # GET EC2 ID FROM EVENT
    instance_id = event['detail']['EC2InstanceId']
    try:
        eni_ids = []
        eni_attach_ids = []
    # GET NETWORK INTERFACES DETAILS FROM EC2    
        response = ec2.describe_instances(
            InstanceIds=[
                str(instance_id)
            ],
        )
        raw_data = response['Reservations'][0]['Instances'][0]['NetworkInterfaces']
        
        for eni in raw_data:
            if eni['Attachment']['DeviceIndex'] != 0:
                eni_ids.append(eni['NetworkInterfaceId'])
                eni_attach_ids.append(eni['Attachment']['AttachmentId'])

    # DETACH NETWORK INTERFACES FROM EC2 BEFORE DELETING

        for eni_to_detach in eni_attach_ids:
            logger.info('DETACHING ENI: {} BEFORE DELETE.'.format(eni_to_detach))
            detach_enis = ec2.detach_network_interface(
                AttachmentId=str(eni_to_detach),
                Force=True
            )
            logger.info('ENI: {} DETACHED SUCCESSFULLY.'.format(eni_to_detach))

    # REMOVE NETWORK INTERFACES 

        for eni_to_delete in eni_ids:
            waiter = ec2.get_waiter('network_interface_available')
            wait = waiter.wait(NetworkInterfaceIds=[str(eni_to_delete)])
            logger.info('REMOVING ENI: {}'.format(eni_to_delete))       
            remove_eni = ec2.delete_network_interface(
                NetworkInterfaceId=str(eni_to_delete),
            )
            logger.info('SUCCESSFULLY REMOVED ENI {}; STATUS: {}'.format(eni_to_delete,remove_eni))    
        return

    except Exception as e:
        message = 'FAILED TO DETACH/REMOVE NETWORK INTERFACES. MESSAGE: {}'.format(e)
        logger.error(message)
        raise Exception(message)

def run_command(event):

    # verify eni before create

    eni = []

    # GET EC2 ID FROM EVENT
   
    logger.info('CREATE NETWORK INTERFACE FOR EC2: {}'.format(event['detail']['EC2InstanceId']))

    instance_id = event['detail']['EC2InstanceId']
    
    try:

    # GET EC2 AVAILABILITY ZONE ID and NETWORK INTERFACE INFO

        get_ec2_data = ec2.describe_instances(
            Filters=[
                    {
                        'Name': 'instance-state-name',
                        'Values': [
                            'running',
                        ]
                    },
                ],
            InstanceIds=[
                    instance_id,
                ],)
         
        logger.info('Disable Source/Dest on the Data interface')

        ec2_interfaces = get_ec2_data['Reservations'][0]['Instances'][0]['NetworkInterfaces']


    # DISABLE SOURCE DEST CHECK ON THE DATA INTERFACE

        for data_interface in ec2_interfaces:
            network_interface = ec2_rsr.NetworkInterface(str(data_interface['NetworkInterfaceId']))
            try:
                response = network_interface.modify_attribute(
                        SourceDestCheck={
                            'Value': False
                        }
                    )
                logger.info('Successfully Disabled Source/Dest check on the data interface: {}'.format(data_interface['NetworkInterfaceId']))
            except:
                logger.error('Unable to modify source/dest on the data interface: {}'.format(data_interface['NetworkInterfaceId']))
 
        logger.info('INITIAL ASG EC2 CREATE REQUEST RECEIVED - PROCEEDING TO CREATE AND ATTACH NETWORK INTERFACES')
        instance_az = get_ec2_data['Reservations'][0]['Instances'][0]['Placement']['AvailabilityZone']
        logger.info('CREATING NETWORK INTERFACE IN AZ: {}'.format(instance_az))

        # GET MGMT SUBNET ID BASED ON TAG NAME

        get_mgmt_subnet = ec2.describe_subnets(
            Filters=[
                        {
                            'Name': 'tag:Name',
                            'Values': [
                                str(env_vars['mgmt_subnet_az1']),
                                str(env_vars['mgmt_subnet_az2']), # os.environ
                                ]
                        },
                        {
                            'Name': 'availabilityZone',
                            'Values': [
                                instance_az,
                            ]
                        },        
                    ],
                )
        logger.info('DEBUG: {}'.format(get_mgmt_subnet))
        mgmt_subent_id = get_mgmt_subnet['Subnets'][0]['SubnetId']
        logger.info('DEBUG: {}'.format(mgmt_subent_id))

        # GET SECURITY GROUP ID BASED ON TAG NAME

        get_mgmt_sg_id = ec2.describe_security_groups(
            Filters=[
                {
                    'Name': 'tag:Name',
                    'Values': [
                        str(env_vars['mgmt_sg']), # os.environ
                    ]
                },
            ]
        )
        logger.info('DEBUG: {}'.format(get_mgmt_sg_id))
        mgmt_sg_id = get_mgmt_sg_id['SecurityGroups'][0]['GroupId']
        logger.info('DEBUG: {}'.format(mgmt_sg_id))
        
        logger.info('SECURITY GROUP ID TO ATTACH TO THE ENI: {}'.format(mgmt_sg_id)) 

        
        # CREATE MGMT NETWORK INTERFACE
        logger.info('CREATE MGMT NETWORK INTERFACE IN SUBNET: {}'.format(mgmt_subent_id))  
        create_eni_mgmt = ec2.create_network_interface(
                Description='AWS Lambda Created ENI - MGMT',
                Groups=[str(mgmt_sg_id)],
                SubnetId=str(mgmt_subent_id),
                TagSpecifications=[
                        {
                            'ResourceType': 'network-interface',
                            'Tags': [
                                {
                                    'Key': 'Name',
                                    'Value': "mgmt-eni-"+instance_az
                                    },
                                ]
                            },
                        ],
                    )
        mgmt_eni_id = create_eni_mgmt['NetworkInterface']['NetworkInterfaceId']
        logger.info('WAITING FOR MGMT ENI {} TO BECOME AVAILABLE.'.format(mgmt_eni_id))
        waiter = ec2.get_waiter('network_interface_available')
        wait = waiter.wait(NetworkInterfaceIds=[str(mgmt_eni_id)])
        logger.info('MGMT ENI {} IS NOW AVAILABLE TO ATTACH'.format(mgmt_eni_id))
        


        #ATTACH MGMT ENI TO EC2

        logger.info('ATTACHING MGMT NETWORK INTERFACE: {} TO THE EC2: {}'.format(mgmt_eni_id,instance_id))
        attach_eni_mgmt = ec2.attach_network_interface(
                DeviceIndex=1,
                NetworkInterfaceId=mgmt_eni_id,
                DryRun=False,
                InstanceId=instance_id,
                )                
        if attach_eni_mgmt['ResponseMetadata']['HTTPStatusCode'] == 200:
            message = 'SUCCESSFULLY ATTACHED MGMT ENI TO THE EC2'
            logger.info(message)
        else:
            message = 'MGMT NETWORK INTERFACE ATTACH FAILED!!!!!'
            logger.error(message)
       
         # Update EC2 Tag Name with AZ
         #  
        update_tag = ec2.create_tags(
            Resources=[str(instance_id)],
            Tags = [
                {
                    'Key': 'Name',
                    'Value': str("poc-fw-"+instance_az)
                },
            ]
        )
        return

    except Exception as e:
        message = 'NETWORK INTERFACE CREATION AND ATTACHMENT FAILED: {}'.format(e)
        logger.error(message)
        raise Exception(message)

def lambda_handler(event, context):

    message = 'ASG LIFECYCLE EVENT RECEIVED. EVENT DATA:- {}'.format(event)
    logger.info(message)

    
    if event['detail']['LifecycleTransition'] == "autoscaling:EC2_INSTANCE_LAUNCHING":
        try:
            run_command(event)
            send_lifecycle_action(event, 'CONTINUE')
            message = 'SUCCESS: LIFECYCLE ACTION COMPLETED'
            logger.info(message)
            return message

        except Exception as e:
            send_lifecycle_action(event, 'ABANDON')
            message = 'FAILED: LIFECYCLE ACTION FAILED. MESSAGE: {}'.format(e)
            logger.error(message)            
            raise Exception(message)


    elif event['detail']['LifecycleTransition'] == "autoscaling:EC2_INSTANCE_TERMINATING":
        try:
            remove_interfaces(event)
            send_lifecycle_action(event, 'CONTINUE')
            message = 'SUCCESS: LIFECYCLE ACTION COMPLETED'
            logger.info(message)
            return message
            
        except Exception as e:
            send_lifecycle_action(event, 'ABANDON')
            message = 'FAILED: LIFECYCLE ACTION FAILED. MESSAGE: {}'.format(e)
            logger.error(message)            
            raise Exception(message)

    else:
        message = 'LIFECYCLE TRANSITION CONDITION NOT MET.'
        logger.error(message)
        return message