variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "k8s-lab"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ssh_key_public_path" {
  description = "Path to your local SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "use_default_vpc" {
  description = "Whether to use default VPC instead of creating a new one"
  type        = bool
  default     = true
}
