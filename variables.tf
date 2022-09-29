variable "region_main" {
  type        = string
  description = "The AWS Region that the resources will be created in. Will also be included as part of the IPAM operating region."
  default     = "eu-west-1"
}

variable "region_additional" {
  type        = list(string)
  description = "Additional AWS VPC IPAM operating regions. You can only create VPCs from a pool whose locale matches this variable. Duplicate values will be removed."
  default     = ["eu-central-1"]
}

variable "top_level_pool_cidr" {
  type        = string
  description = "The top level IPAM pool CIDR. Currently only supports a single CIDR."
  default     = "10.0.0.0/8"
}

variable "envs" {
  type = map(any)
  default = {
    0 = {
      "cidr-main" : "10.0.0.0/16"
      "environment" : "dev"
    },
    1 = {
      "cidr-main" : "10.1.0.0/16"
      "environment" : "qa"
    },
    2 = {
      "cidr-main" : "10.2.0.0/16"
      "environment" : "prod"
    }
  }
}

locals {
  deduplicated_region_list = toset(concat([var.region_main], var.region_additional))
}
