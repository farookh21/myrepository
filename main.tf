provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
  access_key = "AKIAVIPLUTVQPDKHMUQX"
  secret_key = "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"
}

#-------------VPC-----------

resource "aws_vpc" "wp_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wp_vpc"
  }
}

#internet gateway

resource "aws_internet_gateway" "wp_internet_gateway" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  tags = {
    Name = "wp_igw"
  }
}

# Route tables

resource "aws_route_table" "wp_public_rt" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.wp_internet_gateway.id}"
  }

  tags = {
    Name = "wp_public"
  }
}

resource "aws_default_route_table" "wp_private_rt" {
  default_route_table_id = "${aws_vpc.wp_vpc.default_route_table_id}"

  tags = {
    Name = "wp_private"
  }
}

resource "aws_subnet" "wp_public1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  #availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "wp_public1"
  }
}


resource "aws_subnet" "wp_private1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  #availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "wp_private1"
  }
}

resource "aws_subnet" "wp_private2_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  #availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags = {
    Name = "wp_private2"
  }
}

resource "aws_subnet" "wp_rds1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds1"]}"
  map_public_ip_on_launch = false
  #availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags = {
    Name = "wp_rds1"
  }
}

#resource "aws_db_subnet_group" "rds_subnetgroup" {
# name       = "rds_subnetgroup"
# subnet_ids = ["${aws_subnet.wp_rds1_subnet.id}"]
#  tags = {
#   Name = "rds_sng"
# }
#}

#Security groups

resource "aws_security_group" "wp_dev_sg" {
  name        = "wp_dev_sg"
  description = "Used for access to the dev instance"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Public Security group

resource "aws_security_group" "wp_public_sg" {
  name        = "wp_public_sg"
  description = "Used for public and private instances for load balancer access"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  #HTTP 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



#RDS Security Group
resource "aws_security_group" "wp_rds_sg" {
  name        = "wp_rds_sg"
  description = "Used for DB instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  # SQL access from public/private security group

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = ["${aws_security_group.wp_dev_sg.id}",
      "${aws_security_group.wp_public_sg.id}",
      #"${aws_security_group.wp_private_sg.id}",
    ]
  }
}

#------------IAM---------------- 

#S3_access

resource "aws_iam_instance_profile" "ssm_access_profile" {
  name = "ssm_access"
  role = "${aws_iam_role.ssm_access_role.name}"
}

resource "aws_iam_role_policy" "ssm_access_policy" {
  name = "ssm_access_policy"
  role = "${aws_iam_role.ssm_access_role.id}"

  policy = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:*",
      "Resource": "arn:aws:ssm:*:*:parameter/inventory-app/*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ssm_access_role" {
  name = "ssm_access_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
  },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
EOF
}



#------Compute------------

resource "aws_db_instance" "wp_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.6.41"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.dbname}"
  username               = "${var.dbuser}"
  password               = "${var.dbpassword}"
  #db_subnet_group_name   = "${aws_db_subnet_group.wp_rds_subnetgroup.name}"
  #db_subnet_group_name   = "${aws_db_subnet_group.rds_subnetgroup.name}"
  #vpc_security_group_ids = ["${aws_security_group.wp_rds_sg.id}"]
  skip_final_snapshot    = true
}


#web server

resource "aws_instance" "wp_web" {
  instance_type = "${var.web_instance_type}"
  ami           = "${var.web_ami}"

  tags = {
    Name = "wp_web"
  }

  #key_name               = "${aws_key_pair.wp_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.wp_public_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.ssm_access_profile.id}"
  subnet_id              = "${aws_subnet.wp_public1_subnet.id}"

	user_data = <<EOF
#! /bin/bash
# Install Apache Web Server and PHP
yum install -y httpd mysql
amazon-linux-extras install -y php7.2
# Download challenge files
wget https://us-west-2-tcprod.s3.amazonaws.com/courses/ILT-TF-100-ARCHIT/v6.5.2/lab-2-webapp/scripts/inventory-app.zip
unzip inventory-app.zip -d /var/www/html/
# Download and install the AWS SDK for PHP
wget https://github.com/aws/aws-sdk-php/releases/download/3.62.3/aws.zip
unzip aws -d /var/www/html
# Turn on web server
chkconfig httpd on
service httpd start
 
echo "**********************"
echo "Installing SSM Agent"
echo "**********************"
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
 
echo "**********************"
echo "Installing AWS CLI"
echo "**********************"
yum install python3-pip.noarch -y
echo "export PATH=/root/.local/bin:$PATH" >> /root/.bash_profile
source /root/.bash_profile
pip3 install awscli --upgrade --user
aws configure set s3.signature_version s3v4

	EOF

}

output "wp_web" {
  value = "http://${aws_instance.wp_web.public_ip}"
}