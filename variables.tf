variable "instance_ami" {
  description = "Red Hat Enterprise Linux version 8 with High Availability (HVM), EBS General Purpose (SSD) Volume Type, 64-bit (x86)"
}
variable "tags" {}
variable "keyname" {}
variable "managed_instance_type" {}
variable "instance_count" {}
variable "controller_instance_type" {}
variable "region" {}
variable "profile" {}
variable "security_group" {}
