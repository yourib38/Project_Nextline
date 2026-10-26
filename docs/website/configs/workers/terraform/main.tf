variable "session_id" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "node_name" {
  type    = string
  default = "pve002"
}

module "worker" {
  source         = "./modules/session_worker"
  session_id     = var.session_id
  vm_id          = var.vm_id
  node_name      = var.node_name
  ssh_public_key = trimspace(file("/root/.ssh/ansible_key.pub"))
}

output "worker_ip" {
  value = module.worker.worker_ip
}
