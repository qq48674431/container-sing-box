# MikroTik RouterOS 容器安装命令

## 前提条件

| 项目 | 要求 |
|------|------|
| RouterOS 版本 | 7.4+ |
| 架构 | x86_64 |
| container 包 | 已安装（System → Packages 中可见） |

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
/interface/bridge/add name=container

# 给 bridge 分配网关 IP
/ip/address/add address=192.168.101.1/24 interface=container

# 创建 veth（容器内网卡）
/interface/veth/add name=veth-singbox address=192.168.101.2/24 gateway=192.168.101.1

# 将 veth 加入 bridge
/interface/bridge/port/add bridge=container interface=veth-singbox

# NAT — 让容器能访问外网
/ip/firewall/nat/add chain=srcnat action=masquerade src-address=192.168.101.0/24
```

## 三、上传容器文件

将 `singbox-mikrotik.tar` 上传到 MikroTik（通过 Winbox 拖拽、WebFig 上传、或 SCP）：

```bash
scp singbox-mikrotik.tar admin@172.16.18.1:/
```

## 四、创建并启动容器

```routeros
/container
add file=singbox-mikrotik.tar interface=veth-singbox logging=yes \
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
/routing/table/add name=proxy fib

# 添加路由
/ip/route/add dst-address=0.0.0.0/0 gateway=192.168.101.2 routing-table=proxy

# 标记指定设备流量
/ip/firewall/mangle/add chain=prerouting src-address=192.168.1.100 action=mark-routing new-routing-mark=proxy

# 如需按多设备分流，重复上面 mangle 规则修改 src-address 即可
```
