#!/usr/bin/env bash
# Preflight checks for the OpenCTI lab host (Ubuntu Linux VM recommended).
# Prints tool versions, free disk, free memory and whether port 8080 is in use.
set -u

echo "== Tool versions =="
docker --version || echo "MISSING: docker"
docker compose version || echo "MISSING: docker compose plugin"
git --version || echo "MISSING: git"
python3 --version || echo "MISSING: python3"
openssl version || echo "MISSING: openssl"

echo
echo "== Disk (current directory) =="
df -h .

echo
echo "== Memory =="
if command -v free >/dev/null 2>&1; then free -h; else echo "free not available (non-Linux host)"; fi

echo
echo "== Port 8080 =="
if command -v ss >/dev/null 2>&1 && ss -ltn '( sport = :8080 )' | grep -q 8080; then
  echo "WARNING: port 8080 is already in use"
else
  echo "port 8080 looks free"
fi

echo
echo "== vm.max_map_count =="
sysctl -n vm.max_map_count 2>/dev/null || echo "unable to read (non-Linux host?)"
