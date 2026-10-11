#!/usr/bin/env bash
# usage: bash tools/vm/vbox-create-base.sh UBUNTU_22.04_ISO [VM_FOLDER]   (HOST, VirtualBox)
set -euo pipefail
ISO=${1:?usage: $0 ISO [VM_FOLDER]}; DIR=${2:-"$HOME/VirtualBox VMs"}; NAME=${A3_BASE:-a3-base}
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
command -v VBoxManage >/dev/null || { echo "VBoxManage not found" >&2; exit 1; }
if [ "$(uname -m)" = arm64 ] || [ "$(uname -m)" = aarch64 ]; then
    echo "Apple Silicon/Arm host: create the base VM in the VirtualBox GUI instead (setup.md S5)." >&2
    exit 1
fi
[ -f "$ISO" ] || { echo "ISO not found: $ISO" >&2; exit 1; }
if VBoxManage showvminfo "$NAME" >/dev/null 2>&1; then echo "$NAME already exists" >&2; exit 1; fi
VBoxManage createvm --name "$NAME" --ostype Ubuntu_64 --basefolder "$DIR" --register
VBoxManage modifyvm "$NAME" --memory 1024 --cpus 1 --graphicscontroller vmsvga \
  --nic1 nat --nictype1 82540EM --boot1 dvd --boot2 disk --boot3 none --boot4 none
DISK="$DIR/$NAME/$NAME.vdi"
VBoxManage createmedium disk --filename "$DISK" --size 10240 --format VDI
VBoxManage storagectl "$NAME" --name SATA --add sata --controller IntelAhci --portcount 2
VBoxManage storageattach "$NAME" --storagectl SATA --port 0 --device 0 --type hdd --medium "$DISK"
VBoxManage storageattach "$NAME" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$ISO"
VBoxManage sharedfolder add "$NAME" --name a3 --hostpath "$REPO" --automount --auto-mount-point /mnt/a3
echo "Created $NAME. Next: VBoxManage startvm $NAME  -> install Ubuntu (instructions.md VII.4)."
