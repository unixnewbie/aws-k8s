############################################
# Terraform settings and AWS provider setup
############################################

terraform {
  required_providers {
    aws = {
      # Specifies the AWS provider plugin from HashiCorp
      source  = "hashicorp/aws"

      # Ensures Terraform uses AWS provider version 5.x
      version = "~> 5.0"
    }
  }

  # Required Terraform version
  required_version = ">= 1.5.0"
}

provider "aws" {
  # AWS region where resources will be created
  region = var.aws_region
}

############################################
# DATA SOURCE: Fetch the default VPC
############################################

data "aws_vpc" "default" {
  # Tell AWS provider to load the AWS default VPC
  # Each AWS region has one default VPC created automatically
  default = true
}

############################################
# DATA SOURCE: Fetch all subnets in the default VPC
############################################

data "aws_subnets" "default" {
  # Filters allow Terraform to query specific subnets
  filter {
    # Filter name → we filter by VPC ID
    name = "vpc-id"

    # Filter value → ID of the default VPC retrieved above
    values = [data.aws_vpc.default.id]
  }
}

############################################
# RESOURCE: Upload local SSH public key to AWS
############################################

resource "aws_key_pair" "k8s_key" {
  # The name the key pair will have in AWS
  key_name = "${var.project_name}-key"

  # Load the local public key file and upload it to AWS
  public_key = file(var.ssh_key_public_path)
}

############################################
# RESOURCE: Security Group for Kubernetes cluster
############################################

resource "aws_security_group" "k8s_sg" {
  # Name of the security group shown in AWS console
  name = "${var.project_name}-sg"

  # Description for documentation
  description = "Security group for Kubernetes cluster"

  # Attach the SG to the default VPC
  vpc_id = data.aws_vpc.default.id

  ############################################
  # INGRESS RULES — Incoming traffic allowed
  ############################################

  # Allow SSH from anywhere (0.0.0.0/0)
  # IMPORTANT: For production, restrict to your IP
  ingress {
    description = "SSH access"
    from_port   = 22                # SSH port
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]     # Allow from ALL IPs
  }

  # Allow Kubernetes API server port (6443)
  # Required for worker nodes to join the control plane
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]     # For labs, allow all
  }

  # Allow all traffic among nodes inside this security group
  # This is important because Kubernetes nodes talk to each other
  ingress {
    description = "Internal cluster communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"              # -1 = all protocols
    self        = true              # Allow SG-to-SG traffic
  }

  ############################################
  # EGRESS RULE — Outgoing traffic allowed
  ############################################

  # Allow all outbound traffic so nodes can reach the internet
  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"              # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]     # Allow to anywhere
  }

  # Add identifying tags to the security group
  tags = {
    Name = "${var.project_name}-sg"
  }
}

############################################
# DATA SOURCE: Latest Ubuntu 22.04 AMI
############################################

data "aws_ami" "ubuntu" {
  # Always pick the newest matching AMI
  most_recent = true

  # Filter for Jammy 22.04 Ubuntu AMI names
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  # Require HVM virtualization
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical is the owner of official Ubuntu images
  owners = ["099720109477"]
}

############################################
# LOCAL VALUE: List of Kubernetes nodes
############################################

locals {
  # The keys represent node hostnames
  # Each entry has a "role" which is used in tags
  nodes = {
    control-plane = { role = "control-plane" }
    worker-1      = { role = "worker" }
    worker-2      = { role = "worker" }
  }
}

############################################
# RESOURCE: EC2 instance creation (3 instances)
############################################

resource "aws_instance" "k8s" {
  # Creates one EC2 instance per entry in locals.nodes map
  for_each = local.nodes

  ###############################
  # Instance OS & Hardware
  ###############################

  # Use Ubuntu AMI we fetched earlier
  ami = data.aws_ami.ubuntu.id

  # Instance type (t3.medium by default)
  instance_type = var.instance_type

  ###############################
  # Networking
  ###############################

  # Use the first subnet in the default VPC
  subnet_id = data.aws_subnets.default.ids[0]

  # Use the SSH key we uploaded to AWS
  key_name = aws_key_pair.k8s_key.key_name

  # Attach the Kubernetes security group
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  # Ensure instance gets a public IP for SSH access
  associate_public_ip_address = true

  ###############################
  # Metadata / Tags
  ###############################

  tags = {
    # Name in AWS console becomes:
    #   project-nodeName
    # Example: k8s-lab-control-plane
    Name = "${var.project_name}-${each.key}"

    # The Kubernetes role (control-plane or worker)
    k8s_role = each.value.role
  }
}
