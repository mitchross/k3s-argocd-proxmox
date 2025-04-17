terraform {
    required_providers {
        proxmox = {
            source = "telmate/proxmox"
        }
    }
}

provider "proxmox" {
    pm_api_url          = "https://192.168.10.11:8006/api2/json"
    pm_api_token_id     = "terraform@pam!terraform"
    pm_api_token_secret = "058d0f5c-ee46-4fcf-83c3-cc4a7c3bb4c0"
    pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "vm-instance" {
    name                = "vm-instance"
    target_node         = "proxmox-threadripper"
    clone               = "talos-v1.9.5-cloud-init-template" // Virtual Machine 9700 (talos-v1.9.5-cloud-init-template) on node 'proxmox-threadripper
    full_clone          = true
    cores               = 2
    memory              = 2048

    disk {
        size            = "32G"
        type            = "scsi"
        storage         = "local-lvm"
        discard         = "on"
    }

    network {
        model     = "virtio"
        bridge    = "vmbr0"
        firewall  = false
        link_down = false
    }

}