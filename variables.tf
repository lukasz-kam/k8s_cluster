variable "aws_region" {
  description = "The AWS region for the infrastructure."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1,2}$", var.aws_region))
    error_message = "The AWS region must be in a valid format (e.g., 'us-east-1', 'eu-central-1')."
  }
}

variable "ssh_access_enabled" {
  description = "Controls whether the SSH ingress rule should be created."
  type        = bool
  default     = false
}

variable "allowed_ip" {
  description = "The IP address allowed for connections with SSH."
  type        = string
}

variable "subnet_az_a" {
  description = "AZ for the public subnet"
  type        = string
  default     = "eu-central-1a"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1,2}[a-z]$", var.subnet_az_a))
    error_message = "The Availability Zone (AZ) must be in a valid AWS format (e.g., 'us-east-1a', 'eu-central-1b'). It should start with a region prefix and end with a lowercase letter."
  }
}

variable "subnet_az_b" {
  description = "AZ for the public subnet"
  type        = string
  default     = "eu-central-1b"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1,2}[a-z]$", var.subnet_az_b))
    error_message = "The Availability Zone (AZ) must be in a valid AWS format (e.g., 'us-east-1a', 'eu-central-1b'). It should start with a region prefix and end with a lowercase letter."
  }
}

variable "vpc_name" {
  description = "Name for the VPC."
  type        = string
  default     = "kube-vpc"
}

variable "domain_name" {
  description = "The domain of the existing Route 53 hosted zone."
  type        = string

  validation {
    condition     = length(regexall("\\.", var.domain_name)) >= 1 && !can(regex("\\s", var.domain_name))
    error_message = "The domain name must contain at least one dot (e.g., 'example.com') and cannot contain spaces."
  }
}

variable "instance_type_worker" {
  description = "Instance type for the worker instance."
  type        = string
  default     = "t2.micro"

  validation {
    condition     = length(var.instance_type_worker) >= 7 && can(regex("\\.", var.instance_type_worker)) && !can(regex("\\s", var.instance_type_worker))
    error_message = "The instance type must be a valid format (e.g., 't2.micro'), be at least 7 characters long, and contain no spaces."
  }
}

variable "instance_type_master" {
  description = "Instance type for the master instance."
  type        = string
  default     = "t2.micro"

  validation {
    condition     = length(var.instance_type_master) >= 7 && can(regex("\\.", var.instance_type_master)) && !can(regex("\\s", var.instance_type_master))
    error_message = "The instance type must be a valid format (e.g., 't2.micro'), be at least 7 characters long, and contain no spaces."
  }
}

variable "ami_id" {
  description = "AMI id for cluster instances."
  type        = string
  default     = "ami-02363a012ffa4a7b4"
}

variable "key_filename" {
  description = "Name of the ssh key file."
  type        = string
  default     = "kube-ssh-key"
}

variable "aws_account" {
  description = "ID of the AWS account."
  type        = string
}