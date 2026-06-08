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
# Variables — override any of these from the CLI or the workflow
# ---------------------------------------------------------------------------

variable "kali_iso_url" {
  description = "Kali Linux installer ISO URL"
  default     = "https://cdimage.kali.org/kali-2024.4/kali-linux-2024.4-installer-amd64.iso"
}

variable "kali_iso_checksum" {
  description = "SHA256 checksum of the ISO"
  default     = "sha256:b1b5f21a3c22b9e88f4384cad8e6c5be00c59779c04f78d01b5e6f18fd9cb7a3"
}

variable "vm_name" {
  description = "Output VM image filename (no extension)"
  default     = "kali-template"
}

variable "output_dir" {
  description = "Directory where the finished image is written"
  default     = "/tmp/kali-output"
}

variable "disk_size" {
  description = "Disk size in MB"
  default     = "20480"   # 20 GB — enough for a demo
}

variable "memory" {
  description = "RAM in MB"
  default     = "2048"
}

variable "cpus" {
  default = "2"
}

variable "ssh_password" {
  description = "Password set by preseed for the kali user"
  default     = "kali"
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Source — QEMU builder
# ---------------------------------------------------------------------------

source "qemu" "kali" {
  # --- ISO ----------------------------------------------------------------
  iso_url      = var.kali_iso_url
  iso_checksum = var.kali_iso_checksum

  # --- Output -------------------------------------------------------------
  output_directory = var.output_dir
  vm_name          = "${var.vm_name}.qcow2"
  format           = "qcow2"

  # --- Hardware -----------------------------------------------------------
  disk_size  = var.disk_size
  memory     = var.memory
  cpus       = var.cpus
  accelerator = "kvm"       # requires KVM on the runner; falls back to tcg if absent
  headless   = true

  # --- SSH access (Packer uses this to run provisioners) ------------------
  communicator = "ssh"
  ssh_username = "kali"
  ssh_password = var.ssh_password
  ssh_timeout  = "45m"

  # --- Shutdown -----------------------------------------------------------
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  # --- Boot (points to our preseed over HTTP) -----------------------------
  boot_wait = "6s"
  boot_command = [
    "<esc><wait>",
    "auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "hostname=kali-template domain=local ",
    "net.ifnames=0 biosdevname=0<enter>"
  ]

  # Packer serves this directory as a tiny HTTP server during the build
  http_directory = "http"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build {
  name    = "kali-demo"
  sources = ["source.qemu.kali"]

  # Minimal post-install hardening / cleanup
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | sudo -S bash -c '{{ .Path }}'"
    scripts = [
      "scripts/01-base.sh"
    ]
  }

  # Write a simple build manifest alongside the image
  post-processor "manifest" {
    output     = "${var.output_dir}/build-manifest.json"
    strip_path = true
  }
}
