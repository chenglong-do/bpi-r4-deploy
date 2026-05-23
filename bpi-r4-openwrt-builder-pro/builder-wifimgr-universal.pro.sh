#!/bin/bash
set -euo pipefail

# Validated source commits (v1.1.1, 2026-05-14):
#   OpenWrt:  99211b26fb3b9ed71d065a1fa35ce54a0d883944  (openwrt-25.12)
#   MTK SDK:  dbf10418baf257033cf4c590f098db1022496dc6  (tarball in repo-cache/mtk-openwrt-feeds.tar.gz)
OPENWRT_COMMIT=${OPENWRT_COMMIT:-99211b26fb3b9ed71d065a1fa35ce54a0d883944}

rm -rf openwrt
rm -rf mtk-openwrt-feeds

git clone --branch openwrt-25.12 https://git.openwrt.org/openwrt/openwrt.git openwrt
cd openwrt; git checkout ${OPENWRT_COMMIT}; cd -;

tar xzf repo-cache/mtk-openwrt-feeds.tar.gz
mv mtk-clone mtk-openwrt-feeds

#\cp -r my_files/feed_revision mtk-openwrt-feeds/autobuild/unified/

\cp -r my_files/999-sfp-10-additional-quirks.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12
\cp -r my_files/999-sfp-11-rtl8261be-mdio-none.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12
\cp -r my_files/999-fix-00-xfrm-sw-sa-offload-ok.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12

\cp -r my_files/MXL862XX/*.patch mtk-openwrt-feeds/25.12/files/target/linux/mediatek/patches-6.12

cd openwrt
bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic prepare

uci/applications
\cp -r ../my_files/luci-app-lite-watchdog/ feeds/luci/applications
\cp -r ../my_files/luci-app-sms-tool-js-main/luci-app-sms-tool-js/ feeds/luci/applications

\cp -r ../my_files/luci-app-wifimgr feeds/luci/applications/luci-app-wifimgr

mkdir -p files/etc/uci-defaults
\cp -r ../my_files/99-set-hostname files/etc/uci-defaults/
chmod +x files/etc/uci-defaults/99-set-hostname

./scripts/feeds update -a
./scripts/feeds install -a

\cp ../my_files/fit.sh package/utils/fitblk/files/fit.sh

\cp -r ../my_files/qmi.sh package/network/utils/uqmi/files/lib/netifd/proto/
chmod -R 755 package/network/utils/uqmi/files/lib/netifd/proto
chmod -R 755 feeds/luci/applications/luci-app-modemdata/root
chmod -R 755 feeds/luci/applications/luci-app-sms-tool-js/root
chmod -R 755 feeds/packages/utils/modemdata/files/usr/share

\cp -r ../configs/my_defconfig-wifimgr-universal-pro .config
make defconfig\cp -r ../my_files/453-w-add-bpi-r4-nvme-dtso.patch target/linux/mediatek/patches-6.12/
\cp -r ../my_files/450-w-nand-mmc-add-bpi-r4.patch package/boot/uboot-mediatek/patches/450-add-bpi-r4.patch
\cp -r ../my_files/451-w-add-bpi-r4-nvme.patch package/boot/uboot-mediatek/patches/451-add-bpi-r4-nvme.patch
\cp ../my_files/452-w-add-bpi-r4-nvme-rfb.patch package/boot/uboot-mediatek/patches/452-add-bpi-r4-nvme-rfb.patch
\cp ../my_files/454-w-add-bpi-r4-nvme-env.patch package/boot/uboot-mediatek/patches/454-add-bpi-r4-nvme-env.patch
\cp -r ../my_files/w-filogic-bpi-r4-universal.pro.mk target/linux/mediatek/image/filogic.mk
\cp ../my_files/arm-trusted-firmware-mediatek-Makefile package/boot/arm-trusted-firmware-mediatek/Makefile


# BPI-R4-Pro patches
\cp -r ../my_files/bpi-r4-pro/patches-kernel/*.patch target/linux/mediatek/patches-6.12/
\cp ../my_files/bpi-r4-pro/patches-uboot/471-add-bpi-r4-pro-8x.patch package/boot/uboot-mediatek/patches/
#\cp ../my_files/bpi-r4-pro/patches-uboot/472-add-bpi-r4-pro-8x-makefile.patch package/boot/uboot-mediatek/patches/
\cp ../my_files/bpi-r4-pro/uboot-mediatek-Makefile package/boot/uboot-mediatek/Makefile
#\cp -r ../my_files/w-sd-nand-mmc-nvme-ddr4-filogic.mk target/linux/mediatek/image/filogic.mk
mv target/linux/mediatek/image/filogic-extra.mk target/linux/mediatek/image/filogic-extra.mk.disabled

echo "CONFIG_BLK_DEV_NVME=y" >> target/linux/mediatek/filogic/config-6.12

\cp -r ../my_files/999-fitblk-02-w-add-bpi-r4-nvme-fitblk.patch target/linux/mediatek/patches-6.12

\cp -r ../my_files/sms-tool/ feeds/packages/utils/sms-tool
\cp -r ../my_files/modemdata-main/ feeds/packages/utils/modemdata 
\cp -r ../my_files/luci-app-modemdata-main/luci-app-modemdata/ feeds/l

echo "CONFIG_PACKAGE_trusted-firmware-a-mt7988-emmc-comb=y" >> .config
echo "CONFIG_PACKAGE_trusted-firmware-a-mt7988-sdmmc-comb=y" >> .config
echo "CONFIG_PACKAGE_trusted-firmware-a-mt7988-spim-nand-ubi-comb=y" >> .config


# MxL862xx DSA switch driver (dangowrt generic patches)
\cp -r ../my_files/bpi-r4-pro/patches-generic-backport/*.patch target/linux/generic/backport-6.12/
\cp -r ../my_files/bpi-r4-pro/patches-generic-pending/*.patch target/linux/generic/pending-6.12/

# Remove conflicting MTK SDK MxL torso patches (superseded by dangowrt complete driver)
rm -f target/linux/mediatek/patches-6.12/732-net-phy-mxl-gpy-don-t-use-SGMII-AN-if-using-phylink.patch
rm -f target/linux/mediatek/patches-6.12/999-dsa-04-add-mxl862xx-tag-formats.patch
rm -f target/linux/mediatek/patches-6.12/999-dsa-05-add-mxl862xx-tag8021q-driver.patch
rm -f target/linux/mediatek/patches-6.12/999-ephy-gpy211-add-mxl862xx-integrated-phy.patch
# Remove mediatek copies of patches already in generic/backport-6.12
rm -f target/linux/mediatek/patches-6.12/772-v7.1-net-dsa-move-dsa_bridge_ports-helper-to-dsa.h.patch
rm -f target/linux/mediatek/patches-6.12/773-v7.1-net-dsa-add-bridge-member-iteration-macro.patch

echo "CONFIG_NET_DSA_MXL862=y" >> .config

bash ../mtk-openwrt-feeds/autobuild/unified/autobuild.sh filogic-mac80211-mt798x_rfb-wifi7_nic build


