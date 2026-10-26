output "worker_id" {
  value = proxmox_virtual_environment_container.worker.vm_id
}

output "worker_ip" {
  value = "192.168.20.${var.vm_id - 200}"
}

output "worker_hostname" {
  value = "worker-${substr(var.session_id, 0, 8)}"
}
