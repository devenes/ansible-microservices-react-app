#! /bin/bash

hostnamectl set-hostname managed-node
dnf update -y
yum update -y