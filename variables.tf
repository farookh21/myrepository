variable "aws_region" {}
variable "aws_profile" {}
variable "vpc_cidr" {}
variable "cidrs" {
  type = "map"
}
variable "localip" {}
variable "db_instance_class" {}
variable "dbname" {}
variable "dbuser" {}
variable "dbpassword" {}
variable "web_instance_type" {}
variable "web_ami" {}
