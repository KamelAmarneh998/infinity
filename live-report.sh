#!/bin/bash
# Infinity live USB: what this computer did with Infinity, in one report, for
# whoever is fixing it. Run in the live session's Terminal:
#
#   curl -fsSL https://kamelamarneh998.github.io/infinity/live-report.sh | bash
#
# It reads (never changes) the graphics driver, the screens and their scale,
# the dock, boot time and the errors of this boot, prints a short summary,
# and uploads the whole report only if you answer "y" (paste.rs, a public paste
# service: the link is random; the report holds no passwords).
set -u
OUT=/tmp/infinity-report.txt
exec 3>&1
{
echo "== Infinity live report $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "-- system"; uname -r; cat /proc/cmdline
sudo dmidecode -s system-manufacturer 2>/dev/null; sudo dmidecode -s baseboard-product-name 2>/dev/null
free -h | head -2
echo "-- graphics, network, sound (and the driver each one uses)"
lspci -nnk | grep -A3 -E 'VGA|3D|Display|Network|Ethernet|Audio' | grep -vE '^--$'
echo "-- modules"; lsmod | grep -E '^(nvidia|nouveau|amdgpu|i915|xe|simpledrm)' || echo "(none of these)"
echo "-- nvidia-smi"; nvidia-smi 2>&1 | head -20
nvidia-smi -q -d PERFORMANCE 2>/dev/null | grep -vE '^\s*$' | head -30
echo "-- nvidia-drm"; grep -H . /sys/module/nvidia_drm/parameters/{modeset,fbdev} 2>&1
echo "-- usb (the stick's speed: 480M = USB 2)"; lsusb -t 2>&1 | head -30
echo "-- busiest processes"; ps -eo pcpu,pmem,rss,comm --sort=-pcpu | head -15
echo "-- drm cards"; for c in /sys/class/drm/card[0-9]*; do [ -e "$c/device/driver" ] && echo "$(basename "$c") $(basename "$(readlink -f "$c/device/driver")")"; done
echo "-- screens (kscreen)"; kscreen-doctor -o 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | head -60
echo "-- panels"
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s \
  "panels().forEach(function (p) { print(p.location + ' screen ' + p.screen + ' height ' + p.height + ' floating ' + p.floating + '\n') }); print('screens ' + screenCount)" 2>&1
for i in 0 1 2; do busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "print(JSON.stringify(screenGeometry($i)))" 2>/dev/null; done
echo "-- kwin"
busctl --user call org.kde.KWin /KWin org.kde.KWin supportInformation 2>&1 | sed 's/\\n/\n/g' |
    grep -iE 'version|platform|renderer|driver|OpenGL|refresh|Name:|Enabled:|Scale|Geometry|VRR|cursor|triple|Compositing|Animation' | head -80
echo "-- our services"
systemctl --user --no-pager status infinity-dock-everywhere infinity-display-scale 2>&1 | grep -E '●|Active|added|scale for'
systemctl --no-pager status infinity-windows-clock infinity-wait-gpu 2>&1 | grep -E '●|Active'
echo "-- clock"; timedatectl 2>&1 | grep -E 'Local|Universal|RTC'
echo "-- boot time"; systemd-analyze 2>&1 | head -2; systemd-analyze blame 2>/dev/null | head -12
echo "-- network"; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>&1
echo "-- errors this boot"; journalctl -b -p err --no-pager 2>/dev/null | tail -60
echo "-- kwin / plasma / brave warnings"
journalctl -b --no-pager 2>/dev/null | grep -iE 'kwin_wayland|plasmashell|brave' | grep -iE 'error|fail|crash|segfault|timeout' | tail -40
echo "-- coredumps"; coredumpctl list --no-pager 2>/dev/null | tail -10
} > "$OUT" 2>&1

# The short summary
driver=$(lspci -nnk | grep -A3 -E 'VGA|3D' | sed -n 's/.*Kernel driver in use: //p' | sort -u | paste -sd, -)
echo
echo "================ Infinity on this computer ================"
echo "Graphics driver in use: ${driver:-none}"
nvidia-smi --query-gpu=name,driver_version,clocks.gr,clocks.max.gr --format=csv,noheader 2>/dev/null | sed 's/^/NVIDIA: /'
kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^Output|Scale|Geometry' | paste -sd' ' | sed 's/Output:/\nScreen:/g' | sed '/^$/d'
echo "Boot: $(systemd-analyze 2>/dev/null | head -1 | sed 's/Startup finished in //')"
echo "Errors this boot: $(journalctl -b -p err --no-pager -q 2>/dev/null | wc -l)"
echo "Full report: $OUT ($(wc -l < "$OUT") lines)"
echo "==========================================================="
echo
read -r -p "Upload the full report so it can be read on the other computer? [y/N] " answer < /dev/tty
if [[ "$answer" == [yY]* ]]; then
    # (0x0.st stopped taking uploads in 2026; the live USB has no nc for termbin)
    link=$(curl -fsS --data-binary "@$OUT" https://paste.rs/ 2>/dev/null)
    if [ -n "$link" ]; then
        echo; echo "Send this link:  $link"; echo
    else
        echo "The upload didn't work. Take a photo of the summary above instead."
    fi
fi
