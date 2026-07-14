variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "storage_gb" {
  type    = number
  default = 20
}

variable "database_name" {
  type    = string
  default = "memos"
}

variable "database_username" {
  type    = string
  default = "memos_user"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}
