#!/usr/bin/env bash
# Run inside the ImmortalWrt source tree after `./scripts/feeds update -a`.
# Required env: GOLANG_BRANCH, UBI_SIZE
set -euo pipefail

# ---- Newer Go toolchain (xray-core / sing-box / hysteria / adguardhome / mosdns) ----
rm -rf feeds/packages/lang/golang
git clone --depth 1 -b "$GOLANG_BRANCH" https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
grep -E '^GO_VERSION_(MAJOR_MINOR|PATCH)' feeds/packages/lang/golang/golang/Makefile

# ---- Let the upstream passwall feeds win over the copies bundled in immortalwrt feeds ----
for dir in feeds/passwall_packages/*/; do
  name=$(basename "$dir")
  find feeds/packages -mindepth 2 -maxdepth 3 -type d -name "$name" -prune -exec rm -rf {} +
done
rm -rf feeds/luci/applications/luci-app-passwall

# ---- mosdns v5 (sbwml); geodata comes from passwall_packages ----
find feeds/packages feeds/luci -mindepth 2 -maxdepth 3 -type d \
  \( -name mosdns -o -name luci-app-mosdns -o -name v2dat \) -prune -exec rm -rf {} +
rm -rf package/mosdns
git clone --depth 1 -b v5 https://github.com/sbwml/luci-app-mosdns package/mosdns
rm -rf package/mosdns/v2ray-geodata

./scripts/feeds update -i
./scripts/feeds install -a -f -p passwall_packages
./scripts/feeds install -a -f -p passwall_luci
./scripts/feeds install -a

# ---- Enlarge UBI to cover the whole 512 MiB NAND ----
dts=target/linux/mediatek/dts/mt7986a-netcore-n60-pro.dts
grep -q 'reg = <0x0580000 0x7a80000>;' "$dts" || {
  echo "::error::ubi partition definition not found in $dts, upstream DTS changed"
  exit 1
}
sed -i "s/reg = <0x0580000 0x7a80000>;/reg = <0x0580000 ${UBI_SIZE}>;/" "$dts"
echo "---- patched ubi partition ----"
grep -n -B2 -A2 "$UBI_SIZE" "$dts"
