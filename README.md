# AN7581 固件编译工程：XG-040G-MD + HG5382A + XG-040G-TF（Lean lede）

同一个仓库编译 **三台** Airoha AN7581DT 设备的自定义固件，源码基于
[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)（master 分支，内核 6.18，LuCI 取自 openwrt-25.12）。

| | 机型 A | 机型 B | 机型 C |
|---|---|---|---|
| 设备名（lede） | `nokia_xg-040g-md-ubi` | `fiberhome_hg5382a` | `nokia_xg-040g-tf-ubi` |
| 厂商 | Nokia Bell（移动定制） | FiberHome 烽火 HG5382A | Nokia Bell（电信定制） |
| 配置文件 | `configs/xg040g-md.config` | `configs/hg5382a.config` | `configs/xg040g-tf.config` |
| 工作流 | `Build LEDE for Nokia XG-040G-MD` | `Build LEDE for FiberHome HG5382A` | `Build LEDE for Nokia XG-040G-TF` |
| Release tag | `build-<N>` | `hg5382a-build-<N>` | `xg040g-tf-build-<N>` |

**三份 config 的插件列表完全一致**（同平台同内核），只有目标机型那 3 行不同。
改插件时如果想保持机型之间一致，记得几份 config 都改。

> 三条工作流的 `on.push.paths` 各自只监听自己的 config + 自己的 yml，互不干扰。

---

## 一、硬件与支持情况

### 机型 A：Nokia XG-040G-MD

| 项目 | 参数 |
|---|---|
| SoC | Airoha AN7581DT，4×Cortex-A53 @1.2GHz + 4 核 NPU |
| 内存 | 512MB DDR4 |
| 闪存 | 256MB SPI NAND（晋华 SkyHigh 或 复旦微 FM25G02B） |
| 网口 | 1×2.5G（EN8811HN）+ 3×千兆 |
| 光口 | XG-PON（ECONET EN7572AN） |
| USB | 1×USB3.0 + 1×USB2.0 |
| 无线 | 无（需外接 AP） |
| lede 设备名 | `nokia_xg-040g-md-ubi`，target `airoha/an7581` |

**注意机型区分**：`XG-040G-MD`（移动定制，量大便宜）✅ / `XG-040G-TF`（电信，量少） / `XG-040G-MF`（**双核 AN7583，别买错**）。

⚠️ **lede 只提供 UBI 布局的镜像**（`-ubi-squashfs-sysupgrade.itb`），且不产出 `preloader.bin` / `bl31-uboot.fip`。
也就是说：**该镜像要求设备已经刷入 OpenWrt U-Boot（或 tcboot）**。
如果你现在还停留在原厂 u-boot + stock 布局，这个镜像刷不进去 —— 那种情况请改用官方 OpenWrt 源码编译 stock 布局版本。

### 机型 B：FiberHome HG5382A（烽火）

与机型 A **同为 `airoha/an7581` target**，共用内核和工具链，因此上面的插件可以原样复用。

| 项目 | 参数 |
|---|---|
| SoC | Airoha AN7581DT（与 Nokia 款同款） |
| lede 设备名 | `fiberhome_hg5382a`，target `airoha/an7581` |
| 2.5G 电口 | 外挂 **MaxLinear GPY211** PHY（`kmod-phy-maxlinear`，由设备定义自动带入） |
| 光口 | XPON，走 `kmod-airoha-xpon` + `kmod-airoha-paged-bosa`（BOSA 光组件，本机专用） |
| PON 管理 | `airoha-ponctl` / `airoha-pond` / `luci-app-pon`（自动带入） |
| 闪存布局 | UBI（`UBOOTENV_IN_UBI=1`、`KERNEL_IN_UBI=1`，走 `fiberhome-ubi-images`） |
| 产物文件名 | `openwrt-airoha-an7581-fiberhome_hg5382a-squashfs-sysupgrade.itb` |

关键差异对比 Nokia 款：

| 差异点 | Nokia XG-040G-MD | FiberHome HG5382A |
|---|---|---|
| 光模块驱动 | `kmod-airoha-en7572` | `kmod-airoha-paged-bosa` |
| 2.5G PHY | EN8811HN（内置） | MaxLinear GPY211（外挂） |
| 设备名后缀 | 带 `-ubi`（选项里有 `-ubi` / 非 ubi 两个 profile） | 无后缀变体，只有 `fiberhome_hg5382a` |

> UBI 布局意味着 **同样要求已刷好 OpenWrt U-Boot**，原厂 stock 布局刷不进去，这一点与 Nokia 款一致。

### 机型 C：Nokia XG-040G-TF（电信版）

与机型 A **同一套 `nokia_xg-040g-md-common` 设备定义**（DEVICE_VENDOR/_DEVICE_MODEL 不同，其余同源），
同样位于 `airoha/an7581` target，产物名 `openwrt-airoha-an7581-nokia_xg-040g-tf-ubi-squashfs-sysupgrade.itb`。

⚠️ **但 lede 在 TF 的定义里主动减掉了三个包**（相对 MD 的 common）：

| 被减掉的包 | 含义 |
|---|---|
| `-kmod-usb3` | **电信版很可能没有可用的 USB3 口** |
| `-kmod-usb-ledtrig-usbport` | 无 USB LED 触发 |
| `-kmod-regulator-userspace-consumer` | 无用户空间调压接口 |

这意味着三份统一插件里的 **USB 段落（QModem 4G/5G 拨号、USB 网卡驱动、USB 存储）在 TF 上大概率找不到对应硬件**，
只会白白占用固件体积。

为了「三机型插件一致」当前仍然全部编入了。若你确认手上这台 TF **确实没有 USB 口**，
把 `configs/xg040g-tf.config` 里「USB 移动网络模块」和「USB 存储支持」两段注释掉，
固件能小几十 MB，256MB NAND 上会宽松不少（见第三节关于 rootfs ≤180MB 的说明）。

其余部分与机型 A 完全相同：同为 UBI 布局（`-ubi` 后缀），同样要求先刷 OpenWrt U-Boot，
光模块同样是 `kmod-airoha-en7572` + `kmod-phy-airoha-en8811h`。

---

## 二、两种编译方式

### 方式 A（推荐）：GitHub Actions 云编译

本工程目录结构：

```
xg040gmd-build/
├── .github/workflows/build-xg040g-md.yml   # 云编译工作流（Nokia MD，移动版）
├── .github/workflows/build-hg5382a.yml     # 云编译工作流（FiberHome）
├── .github/workflows/build-xg040g-tf.yml   # 云编译工作流（Nokia TF，电信版）
├── configs/xg040g-md.config                # 机型 + 插件选择（Nokia MD）
├── configs/hg5382a.config                  # 机型 + 插件选择（FiberHome）
├── configs/xg040g-tf.config                # 机型 + 插件选择（Nokia TF）
├── files/etc/uci-defaults/99-turbo-offload # 首启自动开 flow offloading + BBR（三机型共用）
├── scripts/local-build.sh                  # 本机 WSL 编译脚本
├── 插件清单.md
└── README.md
```

**A-1. 把工程放进 GitHub 仓库**

任选一种：

- *网页上传（国内网络最省事）*：GitHub 新建空仓库 → `Add file` → `Upload files` →
  把 `xg040gmd-build` 里的 **`.github`、`configs`、`files`、`scripts`** 四个目录和 md 文件一起拖进去
  （`.github` 是隐藏目录，Windows 资源管理器里需先开启「显示隐藏项目」）→ `Commit changes`；
- *命令行*：需能访问 github.com（开代理后）
  ```bash
  cd C:/Users/g4560/WorkBuddy/2026-10-31-22-15-10/xg040gmd-build
  git init -b main
  git add -A && git commit -m "init: XG-040G-MD build"
  git remote add origin https://github.com/<你的用户名>/xg040gmd-build.git
  git push -u origin main
  ```

**A-2. 触发编译**

仓库 → **Actions** → 左侧选对应机型的工作流 → 右侧 **Run workflow** → 选 `main` → 运行。

- Nokia MD：`Build LEDE for Nokia XG-040G-MD` → Artifact `lede-xg040g-md-<编号>` → Release `build-<N>`
- FiberHome：`Build LEDE for FiberHome HG5382A` → Artifact `lede-hg5382a-<编号>` → Release `hg5382a-build-<N>`
- Nokia TF：`Build LEDE for Nokia XG-040G-TF` → Artifact `lede-xg040g-tf-<编号>` → Release `xg040g-tf-build-<N>`

工作流会依次：清理磁盘 → 装依赖 → clone lede → 挂 QModem feed → 注入 files/ → 校验机型 → 校验插件 →
`make download` → 编译 → 打包。

> **两条工作流互不干扰**：各自的 `on.push.paths` 只监听自己的 config 和自己的 yml，
> 所以改动 Nokia 的插件不会触发 FiberHome 重编译，反之亦然。
> （例外：改某个 workflow 文件本身会触发它自己，此时可在 Actions 页手动 Cancel。）

**A-3. 取固件**

约 1~2 小时后，在该次运行的页面底部 **Artifacts** 下载 `lede-xg040g-md-<编号>`，解压得到：

- `openwrt-airoha-an7581-nokia_xg-040g-md-ubi-squashfs-sysupgrade.itb` ← 主固件（Nokia MD）
  - FiberHome 对应的是 `openwrt-airoha-an7581-fiberhome_hg5382a-squashfs-sysupgrade.itb`
  - TF 电信版对应的是 `openwrt-airoha-an7581-nokia_xg-040g-tf-ubi-squashfs-sysupgrade.itb`
- `*-recovery.itb`（如产出，UART/initramfs 救砖用）
- `SHA256SUMS.txt`

> 提示：`dl` 下载和编译都在 GitHub 的机器上跑，**完全不依赖你本地网络**。
> 首次编译 90~150 分钟，之后有 `dl` 缓存会快很多（缓存 key 跟着 config 内容变）。

### 方式 B：本机 WSL2 编译

前提：WSL2 里装好 **Debian 12 / Ubuntu 22.04 LTS**（当前机器上 WSL 尚未安装任何发行版，需先 `wsl --install -d Debian`）。

```bash
# 1. 工程必须放在 WSL 的 ext4 里，不能放 /mnt/c（NTFS 大小写不敏感，编译必挂）
wsl -d Debian
cp -r "/mnt/c/Users/g4560/WorkBuddy/2026-10-31-22-15-10/xg040gmd-build" ~/
cd ~/xg040gmd-build

# 2. 一键编译（脚本内已含依赖安装、磁盘检查、文件系统检查、机型校验）
bash scripts/local-build.sh
```

产物：`~/lede-build/lede/bin/targets/airoha/an7581/`

资源要求：**磁盘 ≥40GB**（源码 0.5GB + dl 十几 GB + 编译中间产物），内存建议给 WSL2 ≥8GB
（`C:\Users\<你>\.wslconfig` 里 `memory=8GB`），否则链接阶段易被 OOM kill。

---

## 三、当前已内置的插件

想改插件就编辑对应的 `configs/*.config`，增删 `CONFIG_PACKAGE_xxx=y` 即可。
两个机型当前插件完全一致，想保持同步就两边都改同样的行。

| 分类 | 插件 |
|---|---|
| 中文界面 | `luci-i18n-base-zh-cn`、`luci-i18n-firewall-zh-cn` |
| 主题 | `luci-theme-argon`、`luci-app-argon-config` |
| 系统工具 | `luci-app-ttyd`（网页终端）、`luci-app-filetransfer`、`luci-app-airoha-npu`（NPU 状态） |
| 网络 | `luci-app-upnp`、`luci-app-ddns`、`luci-app-wol`、`luci-app-sqm`、`luci-app-nlbwmon`、`luci-app-zerotier` |
| 文件共享 | `luci-app-samba4`、`ksmbd-tools` |
| **代理** | `luci-app-openclash` + `luci-app-ssr-plus` |
| **加速** | `kmod-tcp-bbr`（内核原生 BBR）+ 防火墙 flow offloading（LuCI 勾选，无需插件） |
| **USB 模组** | `qmodem` + `luci-app-qmodem` / `-hc` / `-sms` / `-monitor`、`sms-tool-js`、`uqmi`、`umbim`、`comgt`、`wwan`、`usb-modeswitch` |
| **USB 模组驱动** | `kmod-usb-serial-option`、`kmod-usb-serial-wwan`、`kmod-usb-serial-sierrawireless`、`kmod-usb-acm`、`kmod-usb-wdm`、`kmod-usb-net-qmi-wwan`、`kmod-usb-net-cdc-mbim`、`kmod-usb-net-cdc-ncm`、`kmod-usb-net-huawei-cdc-ncm`、`kmod-usb-net-rndis`、`kmod-usb-net-cdc-ether` |
| USB 存储 | `kmod-usb-storage*`、`kmod-fs-ext4/vfat/exfat/ntfs3`、`block-mount`、`automount`、`e2fsprogs` |
| Docker | **默认关闭**，需外挂 U 盘后手动取消注释 |

PON 相关（`kmod-airoha-xpon`、`kmod-airoha-en7572`、`airoha-ponctl`、`airoha-pond`、`luci-app-pon`）
由设备定义自动带入，无需手动勾选。

### 3.1 两个特殊说明

**① 不装 TurboACC，改用内核原生加速。**
`luci@openwrt-25.12` 分支已经把 `luci-app-turboacc` 删掉了（只保留在 `openwrt-24.10` 分支），
而且本内核没有 `fast-classifier` / `shortcut-fe` 补丁，强行移植容易编译失败。
TurboACC 干的三件事在这里都能原生实现：

| TurboACC 功能 | 等价做法 |
|---|---|
| 软件流量分载 | LuCI「网络 → 防火墙 → 常规设置」勾选 **软件流量分载**（`option flow_offloading '1'`） |
| 硬件流量分载 | 同上勾选 **硬件流量分载**（`option flow_offloading_hw '1'`，Airoha 支持） |
| BBR 拥塞控制 | 已内置 `kmod-tcp-bbr`，`sysctl net.ipv4.tcp_congestion_control=bbr` 启用 |

**三项目前已由 `files/etc/uci-defaults/99-turbo-offload` 在首次启动时自动完成**（已内置进固件）：
开机即写入 `flow_offloading=1`、`flow_offloading_hw=1`，并把 `default_qdisc=fq`、`tcp_congestion_control=bbr`
写进 `/etc/sysctl.conf`。脚本还带一个保护：**若检测到 SQM/QoS 已启用，就跳过 offloading**（两者冲突）。
保存的配置在重启或 `uci commit` 之后依然有效，不会每次开机重复执行（uci-defaults 只在首启跑一次）。

**② SSR+ 来自 helloworld feed。**
lede 的 `feeds.conf.default` 默认已启用 `helloworld`，`luci-app-ssr-plus` 可直接勾选，
自带 Xray / V2Ray / Shadowsocks 系列核心（体积比 OpenClash 大）。

**③ QModem 需要额外 feed。**
lede 默认把 qmodem 那行注释掉了，构建脚本会自动追加：
`src-git qmodem https://github.com/FUjr/QModem.git`（原 `FUjr/modem_feeds`，已改名）。

> 同时装 OpenClash + SSR+ 大约吃掉 60~80MB 空间，squashfs 根分区务必控制在 180MB 以内，
> 256MB NAND 还要留 UBI 开销与 overlay。装不下时优先删 SSR+ 或 OpenClash 其中一个。

---

## 四、刷机（务必先看完）

> **风险提示**：刷机有变砖可能。这台机器救砖成本低（有 preloader + TTL 就能恢复），但**前提是你备份了原厂分区**。

1. **先备份**：TTL 进去（115200 8N1），把 `mtd0` ~ `mtd16` 全部分区 gzip 备份到 U 盘，尤其 `mtd0`(all_flash)；
2. 确认 NAND 型号：
   ```sh
   dmesg | grep -i -E "spi-nand|nand"
   ```
   - SkyHigh S35ML02G300：U-Boot 支持良好；
   - 复旦微 FM25G02B：原厂 U-Boot 不支持 UBI 布局，需使用带该芯片补丁的 U-Boot（tcboot 或打补丁自行编译），否则**一刷就砖**；
3. 免拆机路径（需超密）：超管登录 `http://192.168.1.1` → 开启 FTP/Samba → 访问
   `http://192.168.1.1/system.cgi?telnet` 开 telnet → `user` 登录后 `su user_ftp` 提权；
   移动默认超密：`CMCCAdmin` / `aDm8H%MdA`，电信：`telecomadmin` / `nE7jA%5m`；
4. 刷入 U-Boot（tcboot.bin 或 `preloader.bin` + `bl31-uboot.fip`）；
5. U-Boot 下写入本固件 `*-sysupgrade.itb`；
6. 首次启动默认地址 **192.168.1.1**，密码 **password**。

刷完不通电/不进系统：接 TTL 看 U-Boot 是否起来 → 起得来就 TFTP/ymodem 重刷；起不来用 MTK/Airoha 工具进 BROM 恢复。

> 以上是 Nokia XG-040G-MD 的流程。**HG5382A 的流程不同**，见下面 4.1。

### 4.1 HG5382A（烽火）刷机要点

HG5382A 是 XGPON 光猫，原厂系统自带 telnet 后门，不需要 TTL 就能拿到 shell：

```sh
# 原厂后台开 telnet 后（设备背面贴纸有 MAC，取最后 6 位，字母大写）
telnet 192.168.1.1
# 用户名: telnetadmin
# 密码:   FH-nE7jA%5m<MAC后6位>
# 提权:   su   →   密码 Fh@<MAC后6位>
```

（这组凭据来自恩山论坛 HG5382A 帖子，不同批次/固件版本可能有差异，失效时请自行搜索最新贴。）

**务必先做三件事：**

1. **备份全部分区**。原厂 `cat /proc/mtd` 大致为 `boot` / `bootflag` / `KernelA`/`RootfsA` / `KernelB`/`RootfsB` /
   `apps` / `frameworka` / `frameworkb` / `factory` / `userlocalct` / `userdata`，逐个 gzip 备份出来；
2. **备份原厂光模块校准数据**。丢校准会导致发光功率异常、温度偏高、OLT 注册困难，
   这是 HG5382A 刷机最容易踩且最不可逆的坑；
3. 本固件是 **UBI 布局**，同样要求先刷好 OpenWrt U-Boot / tcboot。

**已知兼容性坑（论坛反馈）：**

- 部分 **中兴 ZTEG OLT** 在 O5 之后会把光猫踢掉，注册状态在 O3/O5 之间反复横跳。
  解法：LuCI → 网络 → 配置 → OMCI Set → ONU identity，把硬件版本改成 `VX.0`、软件版本改成 `VX.X.X`，保存重启；
- PON 注册不上时先看 `luci-app-pon`（固件已内置）里的光模块信息窗；无线的校准/驅動状态还需自行确认。

---

## 五、常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `OpenWrt can only be built on a case-sensitive filesystem` | 工程在 NTFS/9p 上，移到 WSL ext4 |
| 编译中途被 kill（signal 9） | 内存不足，调大 WSL2 内存或降 `-j` 并发 |
| `make download` 大量 404 / 超时 | 国内网络问题，配代理后重试；已下载的不会重复下 |
| Actions 失败在 `应用配置` | 设备符号未命中，看该步输出的 `grep -iE "nokia\|fiberhome"` 结果 |
| 插件列表里 MISS 一堆 | feed 未更新或包名不同（如 `luci-app-samba` vs `luci-app-samba4`），不影响编译，注意别漏装需要的功能 |
| 想要 TurboACC 那个界面 | 已移除（25.12 分支无此插件）。加速改用防火墙 flow offloading + BBR，效果等价 |
| 硬件分载勾了不生效 | `dmesg | grep -i ppe` 看 Airoha PPE 是否加载；flow offloading 与 SQM/QoS、mwan3 有冲突，需二选一 |
| 校验里 `qmodem` / `luci-app-qmodem` MISS | qmodem feed 没挂上或被墙，看 feeds 步骤是否拉到 `feeds/qmodem` |
| TurboACC 页面能开但没效果 | 本机型为 fw4/nftables，用 `nft list ruleset | grep flow` 确认 offload 规则是否下发；也可直接在「防火墙-常规设置」勾选软件/硬件流量分载 |
| 4G/5G 模组不识别 | 先 `lsusb`、`dmesg | tail`，确认 VID:PID 是否被 `kmod-usb-serial-option` 覆盖；不认识的模组需在 `/etc/usb-mode.json` 或 QModem 里添加 VID:PID |
| 刷入后网口灯不亮 / PON 不通 | lede 该设备 DTS 的 LED 映射与 PON 驱动仍在演进，属已知问题 |

---

## 六、许可与致谢

- 源码：[coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)（按作者要求，二次发布请注明仓库链接）
- 设备支持上游：OpenWrt `airoha: add support for Nokia XG-040G-MD`（Mikhail Zhilkin）
- PON 驱动思路参考：pbs05/ponwrt、gw826943555/openwrt（airoha 分支）
