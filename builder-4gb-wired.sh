#!/bin/bash
set -euo pipefail

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-25.12 https://git.openwrt.org/openwrt/openwrt.git openwrt
cd openwrt; git checkout ${OPENWRT_COMMIT:-6dead2869209f4ff9825f3169c129c5ef04f6273}; cd -;

# 2026-07-06: migrated git01 -> main (git01 frozen; MTK recommends main). Single source of truth.
git clone --branch main https://github.com/mediatek/mtk-openwrt-feeds mtk-openwrt-feeds
( cd mtk-openwrt-feeds && git checkout 822c2f0603614e47ec8496571043431494fd2841 )

#\cp -r my_files/feed_revision mtk-openwrt-feeds/autobuild/unified/

\cp -r my_files/999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12

### tx_power check Ivan Mironov's patch - for defective BE14 boards with defective eeprom flash
\cp -r my_files/100-wifi-mt76-mt7996-Use-tx_power-from-default-fw-if-EEP.patch mtk-openwrt-feeds/autobuild/unified/filogic/mac80211/25.12/files/package/kernel/mt76/patches

\cp -r my_files/999-w-image-bpi-r4-nvme-ddr4.patch mtk-openwrt-feeds/25.12/patches-base/

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic prepare


\cp -r ../my_files/453-w-add-bpi-r4-nvme-dtso.patch target/linux/mediatek/patches-6.12/
\cp -r ../my_files/450-w-nand-mmc-add-bpi-r4.patch package/boot/uboot-mediatek/patches/450-add-bpi-r4.patch
\cp -r ../my_files/451-w-add-bpi-r4-nvme.patch package/boot/uboot-mediatek/patches/451-add-bpi-r4-nvme.patch
\cp ../my_files/452-w-add-bpi-r4-nvme-rfb.patch package/boot/uboot-mediatek/patches/452-add-bpi-r4-nvme-rfb.patch
\cp ../my_files/454-w-add-bpi-r4-nvme-env.patch package/boot/uboot-mediatek/patches/454-add-bpi-r4-nvme-env.patch
\cp -r ../my_files/w-sd-nand-mmc-nvme-comb-filogic.mk target/linux/mediatek/image/filogic.mk

echo "CONFIG_BLK_DEV_NVME=y" >> target/linux/mediatek/filogic/config-6.12

\cp -r ../my_files/999-fitblk-02-w-add-bpi-r4-nvme-fitblk.patch target/linux/mediatek/patches-6.12

#\cp -r ../my_files/sms-tool/ feeds/packages/utils/sms-tool
#\cp -r ../my_files/modemdata-main/ feeds/packages/utils/modemdata
#\cp -r ../my_files/luci-app-modemdata-main/luci-app-modemdata/ feeds/luci/applications
\cp -r ../my_files/luci-app-lite-watchdog/ feeds/luci/applications
#\cp -r ../my_files/luci-app-sms-tool-js-main/luci-app-sms-tool-js/ feeds/luci/applications

mkdir -p files/etc/uci-defaults
\cp -r ../my_files/99-set-hostname files/etc/uci-defaults/
chmod +x files/etc/uci-defaults/99-set-hostname
\cp -r ../my_files/99-docker-disable files/etc/uci-defaults/
chmod +x files/etc/uci-defaults/99-docker-disable

git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki feeds/luci/applications/OpenWrt-nikki
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/applications/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config feeds/luci/applications/luci-app-argon-config
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git feeds/luci/applications/lucky

./scripts/feeds update -a
./scripts/feeds install -a

sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' package/feeds/packages/rust/Makefile

\cp ../my_files/fit.sh package/utils/fitblk/files/fit.sh

#\cp -r ../my_files/qmi.sh package/network/utils/uqmi/files/lib/netifd/proto/
#chmod -R 755 package/network/utils/uqmi/files/lib/netifd/proto
#chmod -R 755 feeds/luci/applications/luci-app-modemdata/root
#chmod -R 755 feeds/luci/applications/luci-app-sms-tool-js/root
#chmod -R 755 feeds/packages/utils/modemdata/files/usr/share

\cp -r ../configs/defconfig_wired .config
make defconfig

# Hard-fail if any docker runtime package gets pulled back by dependencies.
if grep -Eq '^(CONFIG_PACKAGE_(docker|dockerd|docker-compose|containerd|runc))=[ym]$' .config; then
	echo "ERROR: Docker-related packages are enabled after defconfig:" >&2
	grep -E '^(CONFIG_PACKAGE_(docker|dockerd|docker-compose|containerd|runc))=' .config >&2 || true
	exit 1
fi


bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic build

exit
