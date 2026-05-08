# MikroTik RouterOS 容器安装命令

## 前提条件

| 项目　　　　　| 要求　　　　　　　　　　　　　　　 |
| ---------------| ------------------------------------|
| RouterOS 版本 | 7.4+　　　　　　　　　　　　　　　 |
| 架构　　　　　| x86_64　　　　　　　　　　　　　　 |
| container 包　| 已安装（System → Packages 中可见） |

---

## 一、启用容器功能

```routeros
/system/device-mode/update container=yes
```

执行后在 **5 分钟内**对设备进行**冷重启**（拔电源 → 等 5 秒 → 插电源）。
x86 设备没有物理复位按钮，必须断电重启，软件重启无效。

验证：

```routeros
/system/device-mode/print
# 确认 container: yes
```

## 二、配置容器网络

```routeros
# 创建容器专用 bridge
/interface/bridge/add name=Linux

# 给 bridge 分配网关 IP
/ip/address/add address=192.168.101.1/24 interface=Linux

# 创建 veth（容器内网卡）
/interface/veth/add name=veth-Linux address=192.168.101.2/24 gateway=192.168.101.1

# 将 veth 加入 bridge
/interface/bridge/port/add bridge=Linux interface=veth-Linux

# NAT — 让容器能访问外网
/ip/firewall/nat/add chain=srcnat action=masquerade src-address=192.168.101.0/24
```

## 三、上传容器文件

将 `May.container.tar` 上传到 MikroTik（通过 Winbox 拖拽、WebFig 上传、或 SCP）：

## 四、创建并启动容器

```routeros
/container
add file=May.container.tar interface=veth-Linux logging=yes \
    name=singbox root-dir=/root start-on-boot=yes workdir=/

# 等待系统解压完成
:delay 5s
/container start singbox
```

查看日志确认导入成功（出现 `import done`）：

```routeros
/log/print where topics~"container"
```

## 五、验证

查看容器状态（`R` = 运行中）：

```routeros
/container/print
```

浏览器访问 Web 管理面板：

```
http://192.168.101.2:8080
```

正常启动后日志会显示：

```
*** started /opt/sing-box/sing-box run -c /opt/sing-box/config.json
路由后台启动成功: http://localhost:8080
```

---

## 日常管理

```routeros
# 查看状态
/container/print

# 停止
/container/stop singbox

# 启动
/container/start singbox

# 查看日志
/log/print where topics~"container"

# 删除容器（需先停止）
/container/stop singbox
/container/remove singbox

# 进入容器 shell
/container/shell singbox
```

## 路由分流（可选）

将指定设备的流量转发到 sing-box 容器：

```routeros
# 创建路由表
/routing/table/add name=linux fib

# 添加路由：匹配 linux 路由表的流量走容器网关
/ip/route/add dst-address=0.0.0.0/0 gateway=192.168.101.2 routing-table=linux

# Mangle 规则：将地址列表中的设备标记到 linux 路由表
/ip/firewall/mangle/add chain=prerouting action=mark-routing \
    new-routing-mark=linux passthrough=no src-address-list=linux comment="sing-box proxy"
```

### 防火墙地址列表

按网段归类需要分流的设备，供 Mangle 引用：

```routeros
/ip/firewall/address-list
add address=172.16.0.0/24 list=linux
add address=172.16.1.0/24 list=linux
add address=172.16.2.0/24 list=linux
add address=172.16.3.0/24 list=linux
add address=172.16.4.0/24 list=linux
add address=172.16.5.0/24 list=linux
add address=172.16.6.0/24 list=linux
add address=172.16.7.0/24 list=linux
add address=172.16.8.0/24 list=linux
add address=172.16.9.0/24 list=linux
add address=172.16.10.0/24 list=linux
add address=172.16.11.0/24 list=linux
add address=172.16.12.0/24 list=linux
add address=172.16.13.0/24 list=linux
add address=172.16.14.0/24 list=linux
add address=172.16.15.0/24 list=linux
```

> 如需按多设备分流，在地址列表中添加对应网段即可。

<!-- CHECKPOINT id="ckpt_mowfnymj_5g9c4d" time="2026-05-08T04:46:56.011Z" note="auto" fixes=0 questions=0 highlights=0 sections="" -->

<!-- CHECKPOINT id="ckpt_mowh3ehk_duw23m" time="2026-05-08T05:26:56.024Z" note="auto" fixes=0 questions=0 highlights=0 sections="" -->
