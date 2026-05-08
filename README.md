# Sing-box MikroTik Container

基于 [sing-box](https://sing-box.sagernet.org/) 定制版的 MikroTik 容器镜像，自带 Web 管理面板（8080 端口），支持多协议代理导入与设备分流。

## 文件说明

| 文件　　　　　　　　　 | 说明　　　　　　　　　　　　　　　　　　　　　|
| ------------------------| -----------------------------------------------|
| `singbox-mikrotik.tar` | 容器镜像（MikroTik 可直接导入）　　　　　　　 |
| `sing-box`　　　　　　 | 定制版 sing-box 二进制（x86_64，含 Web 面板） |
| `config.json`　　　　　| sing-box 配置（TUN 模式，DNS: 223.5.5.5）　　 |
| `index.html`　　　　　 | Web 管理面板前端　　　　　　　　　　　　　　　|
| `proxy-parser.js`　　　| 代理链接解析库　　　　　　　　　　　　　　　　|
| `install.rsc`　　　　　| MikroTik 一键安装脚本　　　　　　　　　　　　 |
| `Dockerfile`　　　　　 | 容器镜像构建文件　　　　　　　　　　　　　　　|

## MikroTik 一键下载

> 前提：RouterOS 7.4+、x86_64 架构、已安装 container 包、已启用 `container` 设备模式

在 MikroTik Terminal 中执行：

```routeros
/tool/fetch url="https://raw.githubusercontent.com/qq48674431/container-sing-box/main/singbox-mikrotik.tar" dst-path=singbox-mikrotik.tar
```

然后创建并启动容器：

```routeros
/container/add file=singbox-mikrotik.tar interface=veth-Linux logging=yes name=singbox root-dir=/root start-on-boot=yes workdir=/
:delay 5s
/container/start singbox
```

完整手动安装步骤见 [RouterOS-install.md](RouterOS-install.md)。

## 启用容器设备模式（首次）

```routeros
/system/device-mode/update container=yes
```

执行后 **5 分钟内冷重启**（拔电源 → 等 5 秒 → 插电源），软件重启无效。

## 构建说明

见 [build.md](build.md)。

## 容器镜像格式说明

MikroTik 要求 tar 镜像满足以下条件：

| 项目 | 要求 |
|------|------|
| 层文件位置 | `blobs/sha256/<hash>`（OCI 布局） |
| 层文件格式 | **未压缩 tar**（不能是 gzip/zstd） |
| manifest.json | 必须包含 `LayerSources` 字段 |
| 元数据文件 | `manifest.json` + `index.json` + `oci-layout` + `repositories` |
