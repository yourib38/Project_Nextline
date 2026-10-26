resource "proxmox_virtual_environment_container" "worker" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  description   = "BreachOut worker voor sessie ${var.session_id}"
  tags          = ["breachout-worker"]
  unprivileged  = true
  start_on_boot = false
  started       = true

  initialization {
    hostname = "worker-${substr(var.session_id, 0, 8)}"

    dns {
      servers = ["192.168.20.1"]
    }

    ip_config {
      ipv4 {
        address = "192.168.20.${var.vm_id - 200}/24"
        gateway = "192.168.20.1"
      }
    }

    user_account {
      keys = [var.ssh_public_key]
    }
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 20
  }

  operating_system {
    template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    type             = "ubuntu"
  }

  disk {
    datastore_id = "ceph-vm"
    size         = var.disk_gb
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  features {
    nesting = true
  }
}
