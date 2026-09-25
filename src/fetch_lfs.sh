#!/usr/bin/env bash
# Download the Labour Force Survey public use microdata files (Statistics Canada, 71M0001X)
# and record their provenance. About 161 MB.
set -euo pipefail
cd "$(dirname "$0")/../data/raw"
base="https://www150.statcan.gc.ca/n1/pub/71m0001x/2021001"
files="hist/2022-CSV.zip hist/2023-CSV.zip hist/2024-CSV.zip hist/2025-CSV.zip
2026-01-CSV.zip 2026-02-CSV.zip 2026-03-CSV.zip 2026-04-CSV.zip 2026-05-CSV.zip 2026-06-CSV.zip 2026-07-CSV.zip 2026-08-CSV.zip"
echo "[" > sources.json
first=1
for f in $files; do
  out="lfs_$(basename "$f")"
  curl -sSfL --retry 3 -o "$out" "$base/$f"
  sha=$(shasum -a 256 "$out" | awk '{print $1}')
  size=$(stat -f %z "$out" 2>/dev/null || stat -c %s "$out")
  [ $first -eq 1 ] || echo "," >> sources.json
  printf '  {"file": "%s", "url": "%s", "bytes": %s, "sha256": "%s", "retrieved_utc": "%s"}' \
    "$out" "$base/$f" "$size" "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> sources.json
  first=0
  echo "$out $size"
done
echo "" >> sources.json; echo "]" >> sources.json
