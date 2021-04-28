variable "region" {
  default = "us-east-1"
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      rolearn  = "arn:aws:iam::12345678912:user/iamadmin"
      username = "iamadmin"
      groups   = ["system:masters"]
    },
  ]
}