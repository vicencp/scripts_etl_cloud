#!/usr/bin/python3
"""sns_python_publish.py - send a message for each line in stdin

ENVIRONMENT VARIABLES

    SNS_ARN, the SNS arn, default:
    arn:aws:sns:eu-central-1:159146222523:MS_CORE-ipq_events

    AWS_REGION, default:
    eu-central-1
"""

import sys
import boto3
import os

if ("-h" in sys.argv or "--help" in sys.argv):
    print(__doc__)
    sys.exit(0)

SNS_ARN = os.environ.get(
    'SNS_ARN',
    'arn:aws:sns:eu-central-1:159146222523:MS_CORE-ipq_events')
AWS_REGION = os.environ.get(
    'AWS_REGION',
    'eu-central-1')

print(f"SNS={SNS_ARN}", file=sys.stderr)
# Create an SNS client
sns = boto3.client('sns', region_name=AWS_REGION)

for n, line in enumerate(sys.stdin):
    # Publish a simple message to the specified SNS topic
    response = sns.publish(TopicArn=SNS_ARN, Message=line.strip())

    # Print out the response
    print(f"Response no. {n}: {response}")
