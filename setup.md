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
| S4 | VirtualBox and the four private networks | 10 min |
| S5 | Base VM | 40 min |
| S6 | Four VMs from the base | 30 min |
| S7 | Verify the fresh state and record the interface map | 20 min |
| S8 | Later-phase tools (not needed now) | — |
| S9 | Before Phase 0 ends | — |
| Optional | O1 teammate machine · O2 x86-64 test machine · O3 Linux sandbox · O4 extra apps | — |

---

## S0 Locations [you]
- **Repository:** `~/Desktop/COL334 A3` (git, pushed to your private GitHub repo). Note the space in the
  name: in Terminal always write `~/Desktop/"COL334 A3"`. Disks and VMs never go
  inside it.
- **Ubuntu ISO:** `~/Downloads/ubuntu-24.04.x-live-server-arm64.iso` (24.04, not 22.04: see S1).
- **VMs:** `~/A3-VMs/`, laid out exactly like this once S4–S7 are done:

```
~/A3-VMs/
├── a3-base/        Ubuntu install + packages, sealed; snapshot "base-sealed"; never booted again after S6
├── a3-client/      linked clone · adapters LAN_A, LINK_D        · snapshots "fresh", later "netcfg-ok"
├── a3-r1/          linked clone · adapters LAN_A, LAN_B         · snapshots "fresh", later "netcfg-ok"
├── a3-r2/          linked clone · adapters LAN_B, LAN_C, LINK_D · snapshots "fresh", later "netcfg-ok"
├── a3-server/      linked clone · adapters LAN_C                · snapshots "fresh", later "netcfg-ok"
└── a3-transfer.iso read-only CD image of the repo (rebuilt by tools/host/make-transfer-iso.sh)
```
  VirtualBox creates each VM's folder (`.vbox` settings file, disk, `Snapshots/`, `Logs/`). Linked clones
  store only their differences from `a3-base`, so don't delete or move `a3-base`. LAN_A, LAN_B, LAN_C and
  LINK_D are internal-network names, not folders.
- **Inside every VM:**

| Path | What | Writable |
|---|---|---|
| `/mnt/a3` | the repo, from the transfer image (`cat /mnt/a3/TRANSFER_STAMP` shows the build) | no |
| `~/www` | server docroot from `tools/test/gen-www.sh ~/www` (SERVER; any VM for local tests) | yes |
| `~/runs` | your logs, downloads, captures, traces (`mkdir -p ~/runs`) | yes |
| `/tmp` | scratch for test scripts | yes |

## S1 Host tools (macOS, Apple Silicon) [you]
1. If Homebrew is missing, install it from brew.sh. Then in Terminal:
   ```
   brew install git bash grep gnu-sed coreutils zip xorriso
   conda create -n a3 python=3.10 -y && conda activate a3
   ```
   - **bash, grep, gnu-sed, coreutils:** the repo's host scripts need bash ≥ 4 and GNU grep/sed. They find
     these automatically through `tools/host/gnu-path.sh`. Your login shell is unchanged.
   - **conda env `a3` (Python 3.10):** matches the grader's Python 3.10. Homebrew's `python@3.10` fails to
     build on macOS 14, so use conda. Run `conda activate a3` before `setup-dev.sh` and before committing.
2. Download the **Ubuntu Server 24.04 arm64** ISO (the newest `24.04.x`, file name ending
   `live-server-arm64.iso`, not `desktop-arm64.iso`) from `https://cdimage.ubuntu.com/releases/24.04/release/`
   into `~/Downloads`. The 22.04 arm64 server ISO boots to a black screen in VirtualBox on Apple Silicon.
   The grader uses 22.04 x86-64 with Python 3.10; the code only needs the standard library, iproute2 and
   iptables, which behave the same, and the Mac's conda env keeps you honest on Python 3.10.
   Verify it with `shasum -a 256` against that page's `SHA256SUMS`.

**Check:**
- `conda activate a3 && python --version` prints 3.10.x;
- `/opt/homebrew/bin/bash --version` prints 5.x;
- `ggrep --version` prints GNU grep.

## S2 Project folder [Claude] (done 2026-10-10)
The project lives at `~/Desktop/COL334 A3` (moved there from `~/developer/COL334_A3` on 2026-10-10).

**Check:** `ls ~/Desktop/"COL334 A3"` shows `README.md`, `SPEC.md`, `setup.md`, `instructions.md`, `src/`
and `tools/`.

## S3 Git, private remote, dev environment [you]
1. Create a **private** empty repository (GitHub or similar) named `COL334_A3`. It's a backup and your
   history; nobody else needs access.
2. In Terminal:
   ```
   cd ~/Desktop/"COL334 A3"
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

## S4 VirtualBox and the private networks [you]
VirtualBox 7.1 and newer run on Apple Silicon and give **internal networks**: VM-only segments with no
host connection and no DHCP, which handout §1.5 requires.

1. `brew install --cask virtualbox` (a ready-made app, so nothing is compiled), then open VirtualBox once.
   Allow anything macOS asks for (System Settings → Privacy & Security). `VBoxManage --version` must print
   7.1 or newer.
2. There's nothing to create for the networks: an internal network appears as soon as a VM adapter names
   it. We use the names **LAN_A, LAN_B, LAN_C, LINK_D** (S6 does this).
3. Confirm no DHCP server is attached to those names: `VBoxManage list dhcpservers` must not mention them.

**Check:** `bash tools/host/check-host.sh` shows `hypervisor OK`.

## S5 Base VM `a3-base` [you]
1. VirtualBox → **New**:
   - Name `a3-base`, VM Folder `/Users/<you>/A3-VMs`, ISO image: the `ubuntu-24.04.x-live-server-arm64.iso`
   - **untick "Proceed with Unattended Installation"** (VirtualBox 7.1 wording; older versions say "tick
     Skip Unattended Installation"). Its automated install is unreliable on arm64.
   - Once unticked: Type Linux, Version **Ubuntu 24.04 LTS (Noble) (ARM 64-bit)** (or plain Ubuntu ARM
     64-bit). This only picks VirtualBox defaults.
   - Hardware: **1024 MB**, **1 CPU**, **Use EFI ticked** (mandatory on ARM; often greyed out and already
     on); Hard disk: **10 GB**, VDI
   - Make the clones land in the same folder: `mkdir -p ~/A3-VMs` then
     `VBoxManage setproperty machinefolder "$HOME/A3-VMs"` (check with
     `VBoxManage list systemproperties | grep -i "machine folder"`). Typing a not-yet-existing path in
     VirtualBox → Settings → General → Default Machine Folder gives "Invalid settings detected"; create the
     folder first, or pick it via the dropdown → Other…. Skipping this is harmless: clones then go to
     `~/VirtualBox VMs` instead.
2. Settings → **Network → Adapter 1**: attached to **NAT** (installation only; removed in S6). Note the
   *Adapter Type* shown under Advanced; the clones reuse it.
3. Start the VM and install Ubuntu Server:
   - English, default keyboard, **Ubuntu Server** (not minimized)
   - default network (DHCP on the NAT adapter), no proxy, default mirror
   - use the entire disk
   - user `a3`, a password you'll remember, hostname `a3-base`
   - **do not** install OpenSSH and **no** snaps

   Reboot when it says so. If it asks to remove the install medium, just press Enter.
4. **Getting the repo into the VM (transfer image):** on the **Mac**, in `~/Desktop/COL334 A3`:
   ```
   bash tools/host/make-transfer-iso.sh
   ```
   This builds `~/A3-VMs/a3-transfer.iso`, a read-only CD image of the repo (xorriso, with Rock Ridge so the VM
   sees real file names and execute bits; macOS `hdiutil` images show up lowercased and dotless). In VirtualBox, open `a3-base` →
   Settings → **Storage** → click the optical drive → choose that file (replacing the Ubuntu ISO).
   Shared folders are **not** used: no VirtualBox guest additions for Arm Linux guests are set up here.
5. In the VM, log in as `a3`, then:
   ```
   sudo mkdir -p /mnt/a3
   sudo mount -o ro,mode=0555,dmode=0555 /dev/sr0 /mnt/a3 && cat /mnt/a3/TRANSFER_STAMP
   sudo bash /mnt/a3/tools/vm/install-packages.sh
   sudo bash /mnt/a3/tools/vm/seal-base.sh
   sudo poweroff
   ```
   - **install-packages.sh:** installs python3, iproute2, iptables, ethtool, tcpdump, tshark, traceroute,
     curl, wget and netcat, and prints the Python and gcc versions.
   - **seal-base.sh:** turns off cloud-init, moves the installer's netplan file aside so that **no interface
     is configured at boot**, masks the 2-minute "wait for network" boot delay, and persists `rp_filter=1`
     on every interface (the handout's baseline).

**Check, after booting the base once more and logging in:**
- `python3 --version` prints 3.12.x (Ubuntu 24.04; grader-version checks run on the Mac's 3.10 env);
- `ip -br addr` shows interfaces DOWN or without IPv4 (except `lo`);
- `sysctl -a 2>/dev/null | grep '\.rp_filter'` is all `= 1`.

Then power off.

## S6 Four VMs from the base [you: Mac, then each VM]
Everything here can be redone from scratch at any time; `a3-base` and its `base-sealed` snapshot are
never changed. Type every command on **one line** and press Enter only at its end (a `>` prompt means
an unclosed quote: press Ctrl+C and retype).

**6.1 Start clean (Mac).**
1. Power off every VM: in each VM `sudo poweroff`, or VirtualBox → right-click → **Stop → Power Off**.
   All five must show *Powered Off*.
2. Optional: `a3-base` → Settings → **System** → memory **1024 MB** (the clones copy it; 4 × 2 GB is too
   much for most Macs).
3. Terminal:
   ```
   cd ~/Desktop/"COL334 A3"
   bash tools/vm/vbox-clone-topology.sh destroy
   ```
   Prints `deleted a3-client` … for the clones that existed (nothing if none did). VirtualBox now lists
   only `a3-base`. Don't delete `a3-base` or its snapshot.

**6.2 Build the clones and the transfer image (Mac).**
```
brew install xorriso
bash tools/host/make-transfer-iso.sh
bash tools/vm/vbox-clone-topology.sh create
bash tools/vm/vbox-clone-topology.sh transfer
bash tools/vm/vbox-clone-topology.sh map
```
- `make-transfer-iso.sh` → `built …/a3-transfer.iso (…), stamp <date time>`
- `create` → four `created a3-… (adapter type …)` lines, no `WARNING`
- `transfer` → four `a3-…: …/a3-transfer.iso -> …` lines
- `map` → 8 lines `VM adapterN NETWORK MAC`: client LAN_A+LINK_D, r1 LAN_A+LAN_B, r2 LAN_B+LAN_C+LINK_D,
  server LAN_C. Keep this output for S7.

**6.3 Initialise each clone (in the VM; do client, r1, r2, server one after another).**
1. VirtualBox → select `a3-client` → **Start**. Click inside the window (the host key, Left ⌘, releases it).
2. Log in as `a3` (the prompt still says `a3-base login:`; that's expected).
3. Run:
   ```
   sudo mkdir -p /mnt/a3
   sudo mount -o ro /dev/sr0 /mnt/a3
   sudo bash /mnt/a3/tools/vm/node-init.sh client
   sudo reboot
   ```
   Use `r1`, `r2`, `server` in the other VMs. `node-init.sh` sets the hostname (and `/etc/hosts`, so
   `sudo` doesn't complain), writes the one `/etc/fstab` line that mounts the transfer image on `/mnt/a3`
   at every boot, and checks the interface count. It prints `hostname: a3-base -> client`, the fstab
   line, `links: 2 non-lo interfaces (OK)`. Running it twice is harmless.
4. After the reboot (`client login:`), log in and run:
   ```
   bash /mnt/a3/tools/vm/check-fresh.sh
   ```
   Every line must start with `OK` and the last line must be `RESULT: fresh state OK`. It also prints one
   `name interface MAC state` line per interface for S7.

**Expected interface counts:** client 2 · r1 2 · r2 3 · server 1 (besides `lo`).

**Updating the code in the VMs later** (after you or Claude change files on the Mac):
1. Mac: `bash tools/host/make-transfer-iso.sh && bash tools/vm/vbox-clone-topology.sh transfer`
2. Each running VM: `cd ~; sudo umount /mnt/a3; sudo blockdev --flushbufs /dev/sr0; sudo mount /mnt/a3 && cat
   /mnt/a3/TRANSFER_STAMP` (shows the new build time). A guest `sudo reboot` is not enough if the VM
   was running when the image was rebuilt: power it off fully and start it again. VMs that were off pick it up at their next boot.

`/mnt/a3` is read-only, so write logs, captures and downloads to `~` or `/tmp`, never into `/mnt/a3`.

## S7 Verify the fresh state, record the interface map, snapshot [you]
1. **Fresh state:** `check-fresh.sh` (S6.3 step 4) printed `RESULT: fresh state OK` in all four VMs. It
   checks: hostname, transfer image with real names and execute bits, interface count, no IPv4 address,
   no route, every `rp_filter = 1`, `ip_forward = 0`, no netplan file, cloud-init disabled. Any `FAIL`
   line says what to fix; an address or route means DHCP leaked in (S4 step 3, S5 seal).
2. **Interface map:** match each VM's `name interface MAC` lines (from `check-fresh.sh`) with the Mac's
   `map` lines by MAC. That tells you which Linux interface sits on which network, e.g. client
   `enp0s8` = LAN_A. Fill `docs/vm-map.md` (or paste both outputs to Claude, who fills it). These names
   are the arguments to the netcfg scripts.
3. **Isolation check** (once; client and r1 share LAN_A). With `IF` = that VM's LAN_A interface:
   - client: `sudo ip addr add 10.99.0.1/24 dev IF && sudo ip link set IF up`
   - r1: `sudo ip addr add 10.99.0.2/24 dev IF && sudo ip link set IF up`
   - client: `ping -c2 10.99.0.2` must get 2 replies; `ping -c1 -W2 8.8.8.8` must fail
     (`Network is unreachable`).
   - Undo on both: `sudo ip addr flush dev IF && sudo ip link set IF down` (or just reboot).
4. **Screenshots for the report (R1):** each VM → Settings → **Network**, one screenshot per adapter tab
   (Adapter 1–3), saved into `report/screenshots/R1/` on the Mac.
5. **Snapshot:** power off all four (`sudo poweroff` in each), then on the Mac:
   ```
   bash tools/vm/vbox-clone-topology.sh snapshot fresh
   ```
   Prints `a3-client: snapshot fresh` … for all four. Later: `… restore fresh` returns every VM to this
   exact state (fresh-boot tests), and after netcfg works: `… snapshot netcfg-ok`.

**Check:** all four `fresh` snapshots exist, `docs/vm-map.md` is complete, the isolation check passed.
**The environment is ready; Phase 0 can start.**

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
- **Apple Silicon Mac:** S1, then `git clone <private-repo-URL> ~/Desktop/"COL334 A3"`, then
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
| `/mnt/a3` empty after boot | the transfer image isn't inserted: Mac `bash tools/vm/vbox-clone-topology.sh transfer`, then in the VM `sudo mount /mnt/a3` |
| `mount: /dev/sr0: no medium found` | the optical drive is empty; insert the image (row above) |
| `ls /mnt/a3` shows lowercase names (`readme.md`, `gitignore`), `TRANSFER_STAMP` "not found" | image built without Rock Ridge: `brew install xorriso`, rebuild with `make-transfer-iso.sh`, `vbox-clone-topology.sh transfer`, then in the VM `sudo umount /mnt/a3; sudo mount /mnt/a3` |
| `mount: can't find in /etc/fstab` | fstab line mistyped (check spaces, leading `/`, one line): `sudo sed -i '\#/mnt/a3#d' /etc/fstab` and re-add the S6 line |
| `TRANSFER_STAMP` still shows the old time after `transfer` + remount or a guest reboot | the VM was started before the image was rebuilt and VirtualBox still holds the old (deleted) file open; a guest `reboot` keeps the same VirtualBox process. Fix: **power the VM off completely** (`sudo poweroff`, wait for *Powered Off*) and start it again, or re-run `vbox-clone-topology.sh transfer` (it now ejects to an empty drive first, forcing a reopen) and remount |
| Old code in a VM | rebuild and re-insert the image (S6 "Updating the code"); `cat /mnt/a3/TRANSFER_STAMP` shows its build time |
| A clone gets an IPv4 address at boot | a DHCP server is attached to an A3 network (`VBoxManage list dhcpservers`), or S5 seal didn't run: restore `base-sealed`, re-seal, re-clone |
| Boot hangs ~2 min on "wait for network" | `sudo systemctl mask systemd-networkd-wait-online.service` (seal-base does this) |
| Pre-commit hook says "compliance check failed" | read its output; it lists the forbidden API or rule (SPEC §1.5) |
| `package.sh`: `mapfile: command not found` | `brew install bash` (the script re-runs itself under bash ≥ 4) |
| Clones share a MAC | `vbox-clone-topology.sh create` sets `--macaddress auto`; if needed, Settings → Network → Advanced → refresh MAC |
| Our client never completes the handshake; `A3_TRACE=/tmp/t.jsonl` shows `bad-tcp-csum` drops | checksum offload on a virtual link: `sudo ethtool -K <IF> tx off` on the **sending** VM (see instructions.md G3) |
