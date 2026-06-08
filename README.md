# kali-image-automation — Local Demo

Minimal proof-of-concept showing the full pipeline:

```
GitHub Action trigger
  → fetch Kali ISO from cdimage.kali.org
  → verify SHA256 checksum
  → Packer (QEMU builder) installs Kali into a VM
  → output: kali-template.qcow2 on local disk
```

No vSphere required. Runs entirely on your laptop via a WSL Rocky Linux GitHub runner.

---

## Repository layout

```
kali-image-automation/
├── .github/
│   └── workflows/
│       └── build-kali-demo.yml   ← GitHub Actions pipeline
├── packer/
│   └── kali-demo.pkr.hcl         ← Packer QEMU template
├── http/
│   └── preseed.cfg               ← Debian installer automation
├── scripts/
│   ├── 01-base.sh                ← Post-install provisioner
│   └── 99-cleanup.sh             ← Template seal / cleanup
└── README.md
```

---

## Prerequisites on the WSL Rocky Linux runner

### 1. KVM / nested virtualisation

WSL2 supports nested virt, but it must be explicitly enabled. In your Windows `.wslconfig` (at `%USERPROFILE%\.wslconfig`):

```ini
[wsl2]
nestedVirtualization=true
```

Then restart WSL: `wsl --shutdown` and reopen.

Verify inside WSL:
```bash
ls -la /dev/kvm          # must exist
grep -E 'vmx|svm' /proc/cpuinfo | head -1   # must return output
```

### 2. Packages (auto-installed by the workflow, but you can pre-install)

```bash
# Packer
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y packer

# QEMU
sudo dnf install -y qemu-kvm qemu-img

# Add runner user to kvm group
sudo usermod -aG kvm $(whoami)
# Log out and back in, or: newgrp kvm
```

### 3. Disk space

The build needs ~25 GB free in `$TMPDIR` (or wherever `runner.temp` points):
- Kali ISO download: ~4 GB
- Build VM disk: ~20 GB
- Final qcow2 (compressed): ~5–8 GB

---

## Running the pipeline

### Option A — Manual trigger (recommended for demo)

1. Push this repo to GitHub
2. Go to **Actions → Build Kali Demo Template**
3. Click **Run workflow**
4. Watch the live log — each step is clearly labelled

### Option B — Edit and push

Any push to `main` does **not** auto-trigger (only manual + weekly schedule).  
To add a push trigger, add to the workflow:

```yaml
on:
  push:
    branches: [main]
```

---

## Output

After a successful run the template sits on the runner machine at:

```
$RUNNER_TEMP/kali-output/
├── kali-template.qcow2    ← importable VM disk image
└── manifest.json          ← build metadata (name, size, timestamp)
```

You can import the `.qcow2` directly into:
- **QEMU/KVM**: `virt-install --import --disk kali-template.qcow2`
- **VirtualBox**: Convert first: `VBoxManage convertfromraw kali-template.qcow2 kali.vdi`
- **VMware**: `qemu-img convert -f qcow2 -O vmdk kali-template.qcow2 kali.vmdk`

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `KVM: entry failed` or `/dev/kvm not found` | Enable `nestedVirtualization=true` in `.wslconfig`, then `wsl --shutdown` |
| Build stuck at boot for > 10 min | Preseed URL not reachable — check firewall allows the Packer HTTP port (usually 8100-9000) |
| `Permission denied` on `/dev/kvm` | `sudo usermod -aG kvm <runner-user>` then re-login |
| Workflow stays **Queued** | Runner offline — check `sudo ./svc.sh status` in the runner directory |
| ISO checksum mismatch | Kali released a new version — the workflow fetches the checksum dynamically, re-run |

---

## Next steps (production pipeline)

- Swap `source "qemu"` for `source "vsphere-iso"` to target vSphere
- Add cloud-init `GuestInfo` injection for per-VM configuration
- Add Snow Commander approval gate as a workflow job dependency
- Push the QCOW2 to a template registry or object storage
