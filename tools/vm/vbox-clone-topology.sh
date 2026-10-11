#!/usr/bin/env bash
# usage: bash tools/vm/vbox-clone-topology.sh create|transfer [ISO]|map|snapshot NAME|restore NAME|destroy   (HOST, VirtualBox)
set -euo pipefail
BASE=${A3_BASE:-a3-base}
SEAL=base-sealed
NODES="client r1 r2 server"
ISO_DEFAULT="$HOME/A3-VMs/a3-transfer.iso"
nets() { case $1 in client) echo "LAN_A LINK_D";; r1) echo "LAN_A LAN_B";; r2) echo "LAN_B LAN_C LINK_D";; server) echo "LAN_C";; esac; }
info() { VBoxManage showvminfo "$1" --machinereadable; }
state() { info "$1" | sed -n 's/^VMState="\(.*\)"$/\1/p'; }
off() { [ "$(state "$1")" = poweroff ] || [ "$(state "$1")" = aborted ] || { echo "$1 must be powered off" >&2; exit 1; }; }
has_snap() { VBoxManage snapshot "$1" list --machinereadable 2>/dev/null | grep -q "=\"$2\"$"; }
dvd_slot() {
    info "$1" | awk -F'"' '/-IsEjected"=/ { split($2, a, "-IsEjected"); ctl = a[1] }
        $2 ~ /-[0-9]+-[0-9]+$/ && ($4 == "emptydrive" || tolower($4) ~ /\.iso$/) { slot = $2 }
        END { print slot }'
}
insert() {
    local vm=$1 iso=$2 slot ctl port dev
    slot=$(dvd_slot "$vm")
    if [ -z "$slot" ]; then echo "$vm: no optical drive found; add one in Settings → Storage" >&2; return 1; fi
    dev=${slot##*-}; slot=${slot%-*}; port=${slot##*-}; ctl=${slot%-*}
    VBoxManage storageattach "$vm" --storagectl "$ctl" --port "$port" --device "$dev" --type dvddrive \
        --medium emptydrive --forceunmount >/dev/null
    VBoxManage storageattach "$vm" --storagectl "$ctl" --port "$port" --device "$dev" --type dvddrive \
        --medium "$iso" --forceunmount >/dev/null
    echo "$vm: $iso -> $ctl port $port device $dev"
}
case ${1:?usage: $0 create|transfer [ISO]|map|snapshot NAME|restore NAME|destroy} in
    create)
        off "$BASE"
        has_snap "$BASE" "$SEAL" || VBoxManage snapshot "$BASE" take "$SEAL"
        nictype=$(info "$BASE" | sed -n 's/^nictype1="\(.*\)"$/\1/p')
        nictype=${A3_NICTYPE:-${nictype:-virtio}}
        for n in $NODES; do
            vm="a3-$n"
            if VBoxManage showvminfo "$vm" >/dev/null 2>&1; then echo "$vm exists, skipping"; continue; fi
            VBoxManage clonevm "$BASE" --snapshot "$SEAL" --options link --name "$vm" --register >/dev/null
            VBoxManage modifyvm "$vm" --nic1 none --nic2 none --nic3 none --nic4 none
            i=1
            for net in $(nets "$n"); do
                VBoxManage modifyvm "$vm" "--nic$i" intnet "--intnet$i" "$net" "--nictype$i" "$nictype" \
                    "--macaddress$i" auto "--cableconnected$i" on
                i=$((i + 1))
            done
            echo "created $vm: $(nets "$n") (adapter type $nictype)"
        done
        if VBoxManage list dhcpservers | grep -Eq 'NetworkName:.*(LAN_A|LAN_B|LAN_C|LINK_D)'; then
            echo "WARNING: a DHCP server is attached to an A3 network; remove it" >&2
        fi
        ;;
    transfer)
        iso=${2:-$ISO_DEFAULT}
        [ -f "$iso" ] || { echo "no ISO at $iso; run tools/host/make-transfer-iso.sh first" >&2; exit 1; }
        for n in $NODES; do insert "a3-$n" "$iso" || true; done
        echo "running VMs: cd ~; sudo umount /mnt/a3; sudo mount /mnt/a3 && cat /mnt/a3/TRANSFER_STAMP (or power off + start)"
        ;;
    map)
        for n in $NODES; do
            info "a3-$n" | awk -F= -v vm="$n" '
                /^intnet[0-9]=/ { k = substr($1, 7); gsub(/"/, "", $2); net[k] = $2 }
                /^macaddress[0-9]=/ { k = substr($1, 11); gsub(/"/, "", $2); mac[k] = tolower($2) }
                END { for (k = 1; k <= 8; k++) if (k in net) {
                    m = mac[k]; printf "%-7s adapter%d  %-7s %s:%s:%s:%s:%s:%s\n", vm, k, net[k],
                        substr(m,1,2), substr(m,3,2), substr(m,5,2), substr(m,7,2), substr(m,9,2), substr(m,11,2) } }'
        done
        echo "match each MAC with the interface line printed by check-fresh.sh in that VM; fill docs/vm-map.md"
        ;;
    snapshot)
        s=${2:?snapshot name}
        for n in $NODES; do
            off "a3-$n"
            if has_snap "a3-$n" "$s"; then VBoxManage snapshot "a3-$n" delete "$s"; fi
            VBoxManage snapshot "a3-$n" take "$s" >/dev/null && echo "a3-$n: snapshot $s"
        done
        ;;
    restore)
        s=${2:?snapshot name}
        for n in $NODES; do off "a3-$n"; VBoxManage snapshot "a3-$n" restore "$s" && echo "a3-$n: restored $s"; done
        ;;
    destroy)
        for n in $NODES; do VBoxManage unregistervm "a3-$n" --delete 2>/dev/null && echo "deleted a3-$n" || true; done
        ;;
    *) echo "unknown command" >&2; exit 1 ;;
esac
