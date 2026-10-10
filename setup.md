# COL334 A3 — Setup

This is the ordered checklist for preparing **one Apple Silicon Mac** so one person can do the whole
assignment (the solo track, `instructions.md` Part II). It is **not submitted**. Steps S0–S7 are required;
S8–S9 come later. **Optional** extras (a teammate's machine, an x86-64 test machine, the Linux sandbox)
are in the separate section at the end, and nothing in S0–S9 depends on them.
Background is in `instructions.md` Part VII; the design is in `SPEC.md`.

Each step has an **owner** tag:
- **[you]**: macOS GUI, Terminal and installers. Claude cannot type into Terminal on your Mac, so these are
  yours.
- **[Claude]**: file work Claude can do directly in a folder you grant it.

Each step ends with **Check:** lines. Don't move on until they pass.

| Stage | What | Time |
|---|---|---|
| S0 | Decide where things live | 2 min |
| S1 | Host tools (macOS) | 20 min |
| S2 | Project folder on your Mac | 5 min |
| S3 | Git, private remote, dev environment | 15 min |
| S4 | Hypervisor and the four private networks | 20 min |
| S5 | Base VM | 40 min |
| S6 | Four VMs from the base | 30 min |
| S7 | Verify the fresh state and record the interface map | 20 min |
| S8 | Later-phase tools (not needed now) | — |
| S9 | Before Phase 0 ends | — |
| Optional | O1 teammate machine · O2 x86-64 test machine · O3 Linux sandbox · O4 extra apps | — |

---

## S0 Locations [you]
- **Repository:** `~/developer/COL334_A3`. Disks and VMs never go inside it.
- **VMs:** `~/A3-VMs/`.
- **Ubuntu ISO:** `~/Downloads/`.

## S1 Host tools (macOS, Apple Silicon) [you]
1. If Homebrew is missing, install it from brew.sh. Then in Terminal:
   ```
   brew install git bash python@3.10 grep gnu-sed coreutils zip
   ```
   - **bash, grep, gnu-sed, coreutils:** the repo's host scripts need bash ≥ 4 and GNU grep/sed. They find
     these automatically through `tools/host/gnu-path.sh`. Your login shell is unchanged.
   - **python@3.10:** matches the grader's Python 3.10. Use it for unit tests, not your Anaconda Python.
2. Download the **Ubuntu Server 22.04 arm64** ISO (the newest `22.04.x`, file name ending
   `live-server-arm64.iso`) from `https://cdimage.ubuntu.com/releases/22.04/release/` into `~/Downloads`.
   Verify it with `shasum -a 256` against that page's `SHA256SUMS`.

**Check:**
- `python3.10 --version` prints 3.10.x;
- `/opt/homebrew/bin/bash --version` prints 5.x;
- `ggrep --version` prints GNU grep.

## S2 Project folder [Claude] (done 2026-10-10)
Claude places the project at `~/developer/COL334_A3` once you approve folder access to `~/developer`.

**Check:** `ls ~/developer/COL334_A3` shows `README.md`, `SPEC.md`, `setup.md`, `instructions.md`, `src/`
and `tools/`.

## S3 Git, private remote, dev environment [you]
1. Create a **private** empty repository (GitHub or similar) named `COL334_A3`. It's a backup and your
   history; nobody else needs access.
2. In Terminal:
   ```
   cd ~/developer/COL334_A3
   git init -b main
   git config user.name "<your name>"; git config user.email "<your email>"
   bash tools/host/setup-dev.sh
   git add -A && git commit -m "Project scaffold"
   git remote add origin <private-repo-URL> && git push -u origin main
   ```
   `setup-dev.sh` creates `.venv` (Python 3.10 + ruff), points git at `tools/git-hooks/` (the pre-commit
   hook runs the compliance check, ruff and unit tests), sets LF line endings, and runs `check-host.sh`.
3. Use any editor. If you use VS Code (optional, O4), the repo's settings preset the `.venv` interpreter
   and ruff.

**Check:**
- `bash tools/host/check-host.sh` has no MISSING lines, except possibly `hypervisor` until S4;
- the commit succeeded, which means the hook ran;
- the remote shows the files.

## S4 Hypervisor and private networks [you]
VMware Fusion is used on Apple Silicon because it offers private networks with no host connection and no
DHCP, which handout §1.5 requires. VirtualBox doesn't run arm64 guests well, and UTM can't make a shared
private LAN without hand-written QEMU arguments.

1. Download **VMware Fusion Pro** (free for personal use) from Broadcom's support portal. A free Broadcom
   account is required. Install it and allow its system extensions if macOS asks.
2. Fusion → Settings → **Network** → unlock → **+** four times. For each new custom network
   (vmnet2–vmnet5):
   - **untick** "Connect Macs to this network"
   - **untick** "Provide addresses on this network via DHCP"
   - set the subnet to anything; it's ignored because there is no DHCP
3. Record the mapping in `docs/vm-map.md`: vmnet2 = LAN_A, vmnet3 = LAN_B, vmnet4 = LAN_C,
   vmnet5 = LINK_D.

**Check:** `check-host.sh` now shows `hypervisor OK`, and all four networks appear with both boxes unticked.

## S5 Base VM `a3-base` [you]
1. Fusion → New → install from the Ubuntu ISO → Linux / **Ubuntu 64-bit Arm**. Customize:
   - 1 processor core, **1024 MB** memory, **10 GB** disk
   - network: **Share with my Mac** (NAT). This is for installation only and is removed in S6.
   - Sharing → enable shared folders → add `~/developer/COL334_A3` named **`a3`** (read and write)
   - save as `~/A3-VMs/a3-base`
2. Ubuntu installer choices:
   - English, default keyboard, **Ubuntu Server** (not minimized), default network (DHCP), no proxy,
     default mirror
   - use the entire disk (no LVM changes needed)
   - user `a3`, a password you'll remember, hostname `a3-base`
   - **do not** install OpenSSH and **no** snaps
   Reboot when done (if prompted, remove the ISO via Fusion → Virtual Machine → CD/DVD → Disconnect).
3. Log in as `a3`, then:
   ```
   sudo apt-get update && sudo apt-get install -y open-vm-tools
   sudo mkdir -p /mnt/a3
   echo '.host:/a3 /mnt/a3 fuse.vmhgfs-fuse allow_other,defaults,nofail 0 0' | sudo tee -a /etc/fstab
   sudo mount -a && ls /mnt/a3
   sudo bash /mnt/a3/tools/vm/install-packages.sh --vmware
   sudo bash /mnt/a3/tools/vm/seal-base.sh
   sudo poweroff
   ```
   - **install-packages.sh:** installs python3, iproute2, iptables, ethtool, tcpdump, tshark, traceroute,
     curl, wget and netcat, and prints the Python and gcc versions.
   - **seal-base.sh:** turns off cloud-init networking, moves the installer's netplan file aside so that
     **no interface is configured at boot**, masks the 2-minute "wait for network" boot delay, and persists
     `rp_filter=1` on every interface (the handout's baseline).
4. Fusion → Virtual Machine → Snapshots → take snapshot **`base-sealed`**.

**Check, after booting the base once more and logging in:**
- `python3 --version` prints 3.10.x;
- `ip -br addr` shows interfaces DOWN or without IPv4 (except `lo`);
- `sysctl -a 2>/dev/null | grep '\.rp_filter'` is all `= 1`.

Then power off.

## S6 Four VMs from the base [you]
For each of `a3-client`, `a3-r1`, `a3-r2` and `a3-server`:
1. Fusion: select `a3-base` → Virtual Machine → **Create Linked Clone** from `base-sealed` → save as
   `~/A3-VMs/a3-<name>`.
2. Clone settings → Network Adapter:
   - **remove** the NAT adapter
   - **Add Device → Network Adapter** once per network, each set to its custom vmnet:

     | VM | Adapters, in this order |
     |---|---|
     | a3-client | LAN_A, LINK_D |
     | a3-r1 | LAN_A, LAN_B |
     | a3-r2 | LAN_B, LAN_C, LINK_D |
     | a3-server | LAN_C |

   - Under each adapter's **Advanced options**, click **Generate** so every MAC is unique.
3. Keep the shared folder `a3`.
4. Boot, log in, then run `sudo hostnamectl set-hostname <client|r1|r2|server>` and `sudo reboot`.

**Check, in each VM:**
- `hostname` is correct;
- `ls /mnt/a3` works;
- `ip -br link` lists exactly the expected number of non-`lo` interfaces.

## S7 Verify the fresh state and record the interface map [you]
1. In each VM, run:
   ```
   ip -br link; ip -br addr; ip route; sysctl -a 2>/dev/null | grep -E '\.rp_filter'
   ```
   **Expected:** every non-`lo` interface DOWN with no IPv4 address; no routes; every rp_filter = 1.
   Any address or route means DHCP leaked in (repeat S5 step 3 / S4 step 2).
2. Match each interface's MAC (`ip -br link`) to Fusion's adapter MAC (Settings → Network Adapter →
   Advanced) and fill `docs/vm-map.md`.
3. Power everything off. Take snapshot **`fresh`** on each VM.
4. Screenshot each VM's Network Adapter settings into `report/screenshots/R1/` (report item R1).
5. Isolation check (one-time, in any two VMs on the same network):
   `sudo ip addr add 10.99.0.1/24 dev <IF> && sudo ip link set <IF> up` on one, `.2` on the other, then
   `ping -c2` between them. It must work. `ping 8.8.8.8` must fail. Restore `fresh` afterwards.

**Check:** all four `fresh` snapshots exist and `docs/vm-map.md` is complete. **The environment is ready;
Phase 0 can start.**

## S8 Later-phase tools (install when the phase arrives)
| Phase | Tool | macOS |
|---|---|---|
| 15 audit [Rec] | Node.js LTS + Dolos | `brew install node && npm i -g @dodona/dolos` |
| 15 audit [Rec] | JDK + JPlag jar | `brew install --cask temurin`; jar from JPlag's GitHub releases → `tools/audit/` (gitignored) |
| 16 report | pandoc (optional) | `brew install pandoc` + `brew install --cask basictex`, or any word processor exporting PDF |

## S9 Before Phase 0 ends [you]
- Send `docs/ta-questions.md` Q1–Q10. Two matter most for you:
  - **Q10:** may you submit solo, and under what ZIP name?
  - **Q9:** your VMs are arm64 and the grader is x86-64; is that acceptable?

---

## Optional (not part of the solo track)

### O1 Teammate's machine
Only if you work with a partner (two-person split: `instructions.md` Part II-B.1).
- **Apple Silicon Mac:** S1, then `git clone <private-repo-URL> ~/developer/COL334_A3`, then
  `bash tools/host/setup-dev.sh`. They don't need VMs if all VM work happens on your Mac.
- **Any other OS:** Git, Python 3.10 and zip (on Windows, inside WSL2 Ubuntu 22.04), clone, then
  `bash tools/host/setup-dev.sh`.

### O2 x86-64 test machine (strongly suggested if you can borrow one for an hour or two)
The grader runs x86-64; your VMs are arm64. Python behaves identically, so this is a safety check, not a
development requirement. On any x86-64 Windows or Linux machine:
- install VirtualBox 7 (and WSL2 on Windows);
- build the four VMs with the scripted path in `instructions.md` VII.4 "VirtualBox":
  `tools/vm/vbox-create-base.sh`, the Ubuntu install, `install-packages.sh --vbox`, `seal-base.sh`, then
  `tools/vm/vbox-clone-topology.sh create`, `map` and `snapshot fresh`;
- run the Phase 16.4 grader dry run there with your final ZIP.

### O3 Linux network-namespace sandbox
Linux or WSL2 hosts only (not macOS). Recreates the four-machine topology in seconds for quick network
experiments: `sudo bash tools/netns/a3-topology.sh up` (`instructions.md` VII.5). Never a substitute for
the VMs.

### O4 Extra apps
| App | Use | Install |
|---|---|---|
| VS Code | editor with the repo's presets (`.vscode/`) | `brew install --cask visual-studio-code` |
| Wireshark | graphical capture reading; `tcpdump` in the VMs is enough | `brew install --cask wireshark` |
| pandoc | building `report.pdf` from Markdown (S8 lists it too) | `brew install pandoc` |

## Troubleshooting
| Symptom | Fix |
|---|---|
| `/mnt/a3` empty after boot | `sudo apt install open-vm-tools`; check the shared folder is enabled and named `a3`; `sudo mount -a` |
| A clone gets an IPv4 address at boot | the S4 DHCP box is still ticked, or S5 seal didn't run: restore `base-sealed`, re-seal, re-clone |
| Boot hangs ~2 min on "wait for network" | `sudo systemctl mask systemd-networkd-wait-online.service` (seal-base does this) |
| Pre-commit hook says "compliance check failed" | read its output; it lists the forbidden API or rule (SPEC §1.5) |
| `package.sh`: `mapfile: command not found` | `brew install bash` (the script re-runs itself under bash ≥ 4) |
| Clones share a MAC | Advanced options → Generate on every adapter of every clone |
| Our client never completes the handshake; `A3_TRACE=/tmp/t.jsonl` shows `bad-tcp-csum` drops | checksum offload on a virtual link: `sudo ethtool -K <IF> tx off` on the **sending** VM (see instructions.md G3) |
