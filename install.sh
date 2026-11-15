#!/bin/sh
# Connects this system to the Infinity repository and installs infinity-base.
set -e
# A temporary source just for this first install; infinity-base then brings
# the permanent one (and the key), so dpkg never sees a conflicting file.
mkdir -p /etc/infinity
curl -fsSL "https://kamelamarneh998.github.io/infinity/infinity-archive-keyring.gpg" -o /etc/infinity/setup-keyring.gpg
cat > /etc/apt/sources.list.d/infinity-setup.sources <<SRC
Types: deb
URIs: https://kamelamarneh998.github.io/infinity/
Suites: genesis
Components: main
Signed-By: /etc/infinity/setup-keyring.gpg
SRC
apt-get update
apt-get install -y infinity-base
rm -f /etc/apt/sources.list.d/infinity-setup.sources /etc/infinity/setup-keyring.gpg
rmdir /etc/infinity 2>/dev/null || true
apt-get update
echo
echo "Done: Infinity updates now come with: sudo apt update && sudo apt upgrade"
