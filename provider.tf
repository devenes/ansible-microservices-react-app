terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
  # profile    = var.profile
  # access_key = "my-access-key"
  # secret_key = "my-secret-key"
}
