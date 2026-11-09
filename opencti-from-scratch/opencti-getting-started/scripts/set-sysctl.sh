#!/usr/bin/env bash
# Raise vm.max_map_count for Elasticsearch and persist it across reboots.
# Linux host/VM only; requires sudo. On Docker Desktop, change the setting
# inside the Docker VM instead.
set -euo pipefail

sudo sysctl -w vm.max_map_count=1048575
echo 'vm.max_map_count=1048575' | sudo tee /etc/sysctl.d/99-opencti.conf >/dev/null
sudo sysctl --system >/dev/null
echo "vm.max_map_count = $(sysctl -n vm.max_map_count)"
