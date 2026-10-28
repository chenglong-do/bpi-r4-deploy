# RTL8261BE SFP-10G-T on BPI-R4 / BPI-R4 Pro 8X (OpenWrt)

## Result

The Realtek RTL8261BE based copper SFP+ module sold as **OEM SFP-10G-T, vendor revision "A"** works at
10G (9.34 Gbits/sec in iperf3) and at 1G on BPI-R4 with OpenWrt 25.12 + the MediaTek SDK feed
(kernel 6.12.112). Two kernel patches are needed, both in `common/patches/kernel/`.

---

## How the module behaves

- It has **no RollBall I2C-to-MDIO bridge** and the PHY is not reachable from the host at all.
  Page 3 of the 0x51 EEPROM just echoes written bytes, so every RollBall command times out.
- The host side is a SerDes that follows the copper link, and the module **changes its EEPROM identity**
  with it:
  - 10G link partner → `SFP-10G-T`, 10GBASE-R
  - 1G link partner → `SFP-10G-T-I`, 1000BASE-X (still revision "A")
- When the link partner speed changes at runtime (cable moved from a 1G to a 10G port or back),
  the module drops MOD_DEF0 for ~2 s by itself, so the kernel sees a remove/insert and re-reads it.
- At power-on it always starts as `SFP-10G-T` / 10GBASE-R. With a 1G link partner already connected
  it does **not** re-present itself, so the host stays on 10GBASE-R without a link until the module
  is re-read.

## Problems without the patches

1. The upstream quirk forces RollBall for every `OEM SFP-10G-T`. For revision "A" the kernel retries
   the PHY probe 25 times at ~21 s per attempt (over nine minutes), holding `rtnl_lock` for each
   attempt, before it falls back to inband mode.
2. With a 1G link partner at boot there is no link at all (see above).

---

## Fix

### `999-sfp-11-oem-sfp-10g-t-rev-a.patch`

Daniel Pawlik's fixup from openwrt/openwrt#22910 (commit `075ba3b965d4`, mediatek 6.18), rebased onto
6.12: the `OEM SFP-10G-T` quirk gets its own fixup that, for vendor revision `"A   "`, sets
`MDIO_I2C_NONE` (no PHY probe) and keeps the forced 10GBASE-T SFI extended compliance code. Other
revisions (e.g. AQR113C based modules, revision "1" / "02") keep the RollBall fixup unchanged.

This replaces our earlier `999-sfp-11-rtl8261be-mdio-none.patch` (a RollBall bridge probe, the same
approach as upstream 8fe125892f40, which was reverted): its single 200 ms probe could switch slow
genuine RollBall modules to `MDIO_I2C_NONE` for good.

### `999-sfp-22-rtl8261be-boot-1g-reprobe.patch`

Only for modules whose quirk sets `reprobe_no_link` (revision "A" as `SFP-10G-T` and as
`SFP-10G-T-I`), never for modules with a PHY: 15 s after the module reports signal, if the host
netdev still has no carrier, the module is re-read (remove/insert under RTNL and the SFP state machine
mutex), so the host picks up its current identity. At most 20 re-reads; the budget is renewed only
after a host link has been seen.

---

## Test status

BPI-R4 4GB, kernel 6.12.112 + MediaTek SDK patches, 2026-10-28. Old = our previous probe + global re-read (releases of
2026-10-27); new = these two patches (tested by swapping `sfp.ko` / `mdio-i2c.ko` on the release image).

| Case | Old patches | New patches |
|------|------|------|
| Rev A, cold start / power cycle, 1G partner | ✓ 1 re-read, link ~55–60 s | ✓ no PHY probe, 1 re-read, link 54 s |
| Rev A, warm reboot, 1G partner | ✓ 0 re-reads, link 30 s | – |
| Rev A, hot plug, 1G partner | – | ✓ module re-presents itself as `-T-I`, link 16 s after insertion, 0 re-reads |
| Rev A, cable 1G → 10G at runtime | ✓ module re-presents itself, 0 re-reads | ✓ same, link 10G |
| Rev A, cable 10G → 1G at runtime | ✓ module re-presents itself, 0 re-reads | ✓ link 1G (see Notes) |
| Rev A, no cable | ✓ 0 re-reads | – |
| AQR113C (rev 1) | ✓ hot plug, PHY attached | ✓ warm reboot and cold start, RollBall path, PHY ~2.5 s, 0 re-reads |
| `OEM SFP+-T rev 1` (no quirk, no PHY) | ✓ 1G/10G (2026-10-26, with an earlier re-read version that re-read it 4× without cable) | ✓ 1G link, no cable: 0 re-reads |
| Genuine slow RollBall module (e.g. FLYPRO SFP-10GT-CS-30M) | ✗ known to fail with the probe | not available here |

0 RTNL assertions and 0 warnings in all runs. 10G throughput (BPI-R4 ↔ BPI-R4, Cat5e, iperf3 4 streams): **9.34 Gbits/sec**.

## Notes

- Moving the cable from 10G to 1G at runtime makes the MediaTek ethernet driver dump the netsys
  registers and the MT7996 Wi-Fi goes through an L1 SER (incl. WED reset) for ~1 s. Known, not
  addressed; 1G → 10G does not do it.
- BPI-R4 Pro 8X (Combo ports behind the mux) has not been tested with these patches.
