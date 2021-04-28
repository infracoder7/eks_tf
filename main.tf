provider "aws" {
  region = var.region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "test-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.47"

  name                 = "test-vpc"
  cidr                 = "172.46.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.46.1.0/24", "172.46.2.0/24", "172.46.3.0/24"]
  public_subnets       = ["172.46.4.0/24", "172.46.5.0/24", "172.46.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "15.1.0"
  cluster_name    = local.cluster_name
  cluster_version = "1.19"
  subnets         = module.vpc.private_subnets

  tags = {
    Environment = "test"
    Cluster     = local.cluster_name
  }

  vpc_id = module.vpc.vpc_id

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 10
  }

  node_groups = {
    monitoring = {
      desired_capacity = 1
      max_capacity     = 2
      min_capacity     = 1

      instance_types = ["t3.medium"]
      k8s_labels = {
        Environment = "test"
        Cluster     = local.cluster_name
      }
      additional_tags = {
        ExtraTag = "monitoring"
      }
    }
  }

  # Create security group rules to allow communication between pods on workers and pods in managed node groups.
  # Set this to true if you have AWS-Managed node groups and Self-Managed worker groups.
  # See https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1089

  # worker_create_cluster_primary_security_group_rules = true

#   worker_groups_launch_template = [
#     {
#       name                 = "worker-group-1"
#       instance_type        = "t3.small"
#       asg_desired_capacity = 1
#       public_ip            = true
#     }
#   ]

  map_roles    = var.map_roles
}