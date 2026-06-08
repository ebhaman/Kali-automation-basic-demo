packer {
  required_version = ">= 1.9.0"

  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "iso_url" {
  description = "Kali Linux installer ISO URL"
  default     = "https://cdimage.kali.org/kali-2026.1/kali-linux-2026.1-installer-amd64.iso"
}

variable "iso_checksum" {
  description = "SHA256 checksum — fetched dynamically at build time if left as 'none'"
  default     = "none"
  # Set to "none" so the pipeline fetches + verifies the checksum file from
  # kali.org before Packer runs (see the workflow verify step).
  # For a pinned build supply: sha256:<hash>
}

variable "output_dir" {
  description = "Directory where the VM template files are written"
  default     = "/tmp/kali-output"
}

variable "disk_size" {
  description = "VM disk size in MiB"
  default     = "20480"   # 20 GB — enough for a demo, keeps build time short
}

variable "memory" {
  description = "RAM in MiB allocated to the build VM"
  default     = "2048"
}

variable "cpus" {
  description = "vCPUs allocated to the build VM"
  default     = "2"
}

variable "ssh_username" {
  default = "kali"
}

variable "ssh_password" {
  default = "kali"
}

# ---------------------------------------------------------------------------
# Source — QEMU builder (local KVM, no vSphere required)
# ---------------------------------------------------------------------------

source "qemu" "kali" {
  # ISO
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Output
  output_directory = var.output_dir
  vm_name          = "kali-template.qcow2"
  format           = "qcow2"

  # Resources
  disk_size = var.disk_size
  memory    = var.memory
  cpus      = var.cpus

  # KVM acceleration — requires kvm group membership on the runner
  accelerator = "kvm"
  headless    = true

  # HTTP server — serves the preseed.cfg to the installer
  http_directory = "${path.root}/../http"

  # SSH communicator — Packer connects here after install to run provisioners
  communicator  = "ssh"
  ssh_username  = var.ssh_username
  ssh_password  = var.ssh_password
  ssh_timeout   = "60m"

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Boot — send keys to the GRUB menu to start an automated preseed install
  boot_wait = "8s"
  boot_command = [
    "<esc><wait2>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=kali-template domain=local ",
    "DEBIAN_FRONTEND=noninteractive ",
    "--- quiet<enter>"
  ]
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "kali-demo"
  sources = ["source.qemu.kali"]

  # Step 1 — wait for cloud connectivity and update package lists
  provisioner "shell" {
    script = "${path.root}/../scripts/01-base.sh"
    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"
  }

  # Step 2 — cleanup before sealing the template
  provisioner "shell" {
    script = "${path.root}/../scripts/99-cleanup.sh"
    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"
  }

  # Post-processor — write a build manifest (name, size, sha256, timestamp)
  post-processor "manifest" {
    output     = "${var.output_dir}/manifest.json"
    strip_path = true
  }
}
