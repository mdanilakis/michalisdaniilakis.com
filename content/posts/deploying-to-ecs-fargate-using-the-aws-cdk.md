---
title: "Deploying to ECS Fargate using the AWS CDK"
date: 2022-07-14
tags:
- aws
- aws cdk
- ecs
- fargate
- docker
---

AWS CDK is a framework that allows you to build cloud applications by describing AWS resources in your favourite programming language.
<!--more-->

In this post, we will see how we can deploy a simple Flask web application to ECS Fargate using the AWS CDK.

<p></p>
{{< image classes="nocaption fig-50 clear" src="/images/content/cdk-logo-1260x476.png" title="AWS Cloud Development Kit" >}}

## AWS CDK

AWS Cloud Development Kit (CDK) makes it easy to manage cloud infrastructure, enabling developers to use the same
language as the rest of their stack to build cloud applications. CDK supports the use of TypeScript, Python, Java,
.NET/C#, and Go to define reusable components called Constructs.

Constructs represent cloud resources, e.g., an S3 bucket, or a DynamoDB table but also higher-level functionality and patterns
that provide defaults, boilerplate, and configuration to build reliable architectures.

Although CDK looks like yet another IaC tool, in fact, it synthesizes to CloudFormation and is friendlier to developers.
It empowers reusability of infrastructure design patterns among teams and allows rapid development of cloud applications.

## ECS Fargate

Amazon ECS makes it easy for you to [deploy, manage, and scale containerized applications](https://michalisdaniilakis.com/posts/deploying-a-microservice-with-ecs-and-fargate).
Fargate removes the need to manage the lifecycle of computing infrastructure and can be used to run containers without having to provision and manage EC2 instances.

## Deploying a Fargate service

Let's see how we can deploy a Flask application to ECS Fargate using the AWS CDK.

### Prerequisites

* Node.js (10.13.0 or later)
* Docker
* Domain name (and hosted zone in Route 53)
* SSL certificate (issued in AWS Certificate Manager)

First, you need to install and bootstrap the AWS CDK.

```text
npm install -g aws-cdk
cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

Bootstrapping is a process of creating dedicated resources in your account required by the AWS CDK.
These resources include an Amazon S3 bucket, IAM roles, and an ECR repository for storing container images.

### Create the App

Create a directory and initialize the app specifying python as the language.

```text
mkdir aws-cdk-flask-docker
cd aws-cdk-flask-docker
cdk init --language python
```

After the app has been created, also run the following commands to activate the app's Python virtual environment
and install the AWS CDK core dependencies.

```text
source .venv/bin/activate
python -m pip install -r requirements.txt
```

#### Server

Create a directory `server` in the project root directory and define the Dockerfile, server routes, and dependencies.

```text
aws-cdk-flask-docker
|-- aws_cdk_flask_docker
|-- server
|   |-- Dockerfile
|   |-- requirements.txt
|   `-- server.py
`-- app.py
```

The `server.py` file will serve as a minimal example of how to handle HTTP requests
by creating a small web application using the [Flask](https://flask.palletsprojects.com/) framework in Python.

{{< codeblock "server.py" python >}}
from flask import Flask
app = Flask(__name__)


@app.route('/')
def index():
    return 'Hello from Flask!'


@app.route('/health')
def health():
    return 'ok'


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
{{< /codeblock >}}

The `Dockerfile` is used to create a container image that will be deployed to ECS Fargate, it contains a set of instructions
that copy the app sources and uses Python to run the server.

{{< codeblock "Dockerfile" >}}
FROM python:3.9-slim-buster

EXPOSE 5000

WORKDIR /app

COPY ./requirements.txt /app
COPY ./server.py /app

RUN python -m pip install -r requirements.txt

CMD ["python", "server.py"]
{{< /codeblock >}}

#### ECS Fargate Stack

Now that you have your web app ready, you can start creating the cloud stack using the CDK.
You should be able to find and edit a file `aws_cdk_flask_docker_stack.py`, which was created when the app
was initialized using the CDK.

The CDK provides everything that you need to create an ECS Fargate Service with a Load Balancer that will use encrypted
connections. However, you will have to provide an SSL certificate.
You can create a certificate easily in AWS Certificate Manager.

{{< alert info >}}
You must also have a registered domain name (example.com), and a hosted zone in Amazon Route 53.
{{< /alert >}}

> A public hosted zone is a container that holds information about how you want to route traffic on the internet for a specific domain, such as example.com, and its subdomains (acme.example.com, zenith.example.com).

Using the `aws_ecs_patterns`, you can create an `ApplicationLoadBalancedFargateService` and provide the necessary
configuration such as CPU, memory, and routing requirements.

```python
from aws_cdk import (
    Stack,
    aws_ecs_patterns as ecs_patterns,
)
from constructs import Construct


class AwsCdkFlaskDockerStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        # Use ALB + Fargate from ECS patterns
        ecs_patterns.ApplicationLoadBalancedFargateService(...)
```

The Fargate service will be deployed in an ECS cluster, a logical grouping of services that your tasks run.
AWS Fargate removes the need to manage computing infrastructure; AWS manages the ECS cluster capacity for you.

You will also have to provide an AWS VPC, which is a virtual network dedicated to your AWS account.
If you don't have any specific VPC requirements, you can use the default VPC that is provided
in your AWS account.

Finally, you will have to provide the container image and routing options.
The CDK uses Docker to build the container image and uploads that to the ECR repository created
during the bootstrapping process.

{{< codeblock "aws_cdk_flask_docker_stack.py" python >}}
from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_ecs_patterns as ecs_patterns,
    aws_elasticloadbalancingv2 as elb_v2,
    aws_certificatemanager as cert_manager,
    aws_route53 as r53,
)
from constructs import Construct


class AwsCdkFlaskDockerStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Retrieve VPC information
        vpc = ec2.Vpc.from_lookup(
            self, 'VPC',
            # This imports the default VPC but you can also
            # specify a 'vpcName' or 'tags'.
            is_default=True)

        # ECS cluster
        cluster = ecs.Cluster(self, 'MyCluster', vpc=vpc)

        # SSL Certificate (replace with your certificate arn)
        certificate_arn = 'arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE'

        # Use ALB + Fargate from ECS patterns
        service = ecs_patterns.ApplicationLoadBalancedFargateService(
            self, 'MyFlaskApiWithFargate',
            cluster=cluster,
            cpu=256,
            memory_limit_mib=512,
            desired_count=1,
            assign_public_ip=True,
            # Container image
            task_image_options=ecs_patterns.ApplicationLoadBalancedTaskImageOptions(
                image=ecs.ContainerImage.from_asset('./server'),
                container_port=5000),
            # Routing
            public_load_balancer=True,
            protocol=elb_v2.ApplicationProtocol.HTTPS,
            redirect_http=True,
            certificate=cert_manager.Certificate.from_certificate_arn(self, 'cert', certificate_arn),
            # Replace with your domain
            domain_name='cdk-flask-api.example.com.',
            domain_zone=r53.HostedZone.from_lookup(self, "MyHostedZone", domain_name="example.com."))

        # Default target group healthcheck path is /
        # This can be customized
        service.target_group.configure_health_check(path='/health')
{{< /codeblock >}}

To deploy the stack, run the following command(s):

```text
cdk synth  # synthesizes and outputs the AWS CloudFormation template (optional)
cdk deploy # synthesizes and deploys the stack
```

You may have to wait a few minutes for the stack to be created. If you encounter any errors,
you can check the CloudFormation stack and status of every resource on AWS Console.

You can find the complete source [on GitHub](https://github.com/mdanilakis/aws-cdk-flask-docker).

eof.
