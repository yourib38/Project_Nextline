variable "session_id" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "ssh_public_key" {
  type = string
}

variable "node_name" {
  type    = string
  default = "pve002"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "swap" {
  type    = number
  default = 1024
}

variable "disk_gb" {
  type    = number
  default = 25
}
