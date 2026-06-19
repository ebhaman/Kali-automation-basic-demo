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
  description = "SHA256 checksum — fetched dynamically at build time"
  default     = "none"
}

variable "output_dir" {
  description = "Directory where the VM template files are written"
  default     = "/tmp/kali-output"
}

variable "disk_size" {
  description = "VM disk size in MiB"
  default     = "20480"
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

variable "headless" {
  description = "Set false to attach VNC and watch the installer"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Source — QEMU builder
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

  # KVM
  accelerator  = "kvm"
  headless     = var.headless
  qemu_binary  = "qemu-system-x86_64"

  # VNC — connect to localhost:5956 during build to watch the installer
  # (only useful when headless = false)
  vnc_bind_address = "127.0.0.1"
  vnc_port_min     = 5956
  vnc_port_max     = 5956

  # HTTP server — serves preseed.cfg to the installer
  http_directory = "${path.root}/../http"

  # SSH communicator
  communicator  = "ssh"
  ssh_username  = var.ssh_username
  ssh_password  = var.ssh_password
  ssh_timeout   = "90m"
  host_port_min = 2222
  host_port_max = 2222

  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # Boot command — Kali installer ISO (Debian-based) boots a GRUB menu.
  # <esc> drops to the boot: prompt; we then supply the full kernel cmdline
  # pointing the installer at our preseed URL.
  #
  # boot_wait: time to wait for BIOS POST + GRUB to appear before typing.
  # Increase to 20s if the build machine is slow to POST.
  boot_wait = "12s"
  boot_command = [
    "<esc><wait5>",
    "/install.amd/vmlinuz ",
    "initrd=/install.amd/initrd.gz ",
    "auto=true ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=kali-template ",
    "domain=local ",
    "DEBIAN_FRONTEND=noninteractive ",
    "---<enter>"
  ]
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "kali-demo"
  sources = ["source.qemu.kali"]

  provisioner "shell" {
    script          = "${path.root}/../scripts/01-base.sh"
    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"
  }

  provisioner "shell" {
    script          = "${path.root}/../scripts/99-cleanup.sh"
    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"
  }

  post-processor "manifest" {
    output     = "${var.output_dir}/manifest.json"
    strip_path = true
  }
}
