# 容器镜像构建说明

## 构建步骤

在任意一台有 Docker 的 Linux 服务器上操作。

### 1. 准备构建目录

```bash
mkdir -p /root/singbox-build
# 将 sing-box、config.json、index.html、proxy-parser.js 放入该目录
```

### 2. 构建并导出

```bash
cd /root/singbox-build

# 构建镜像
docker build -t singbox-ros:latest .

# 扁平化为单层（减小体积、提高兼容性）
docker create --name tmp-sb singbox-ros:latest
docker export tmp-sb -o rootfs.tar
docker rm tmp-sb

docker import \
  --change 'CMD ["/opt/sing-box/sing-box","run","-c","/opt/sing-box/config.json"]' \
  --change 'WORKDIR /opt/sing-box' \
  --change 'EXPOSE 8080' \
  rootfs.tar singbox:latest

# 保存为 tar
docker save singbox:latest -o singbox-mikrotik.tar
```

### 3. 修复层压缩格式

> **关键步骤**：Docker 29+ 的 `docker save` 输出的层文件是 gzip 压缩的，MikroTik 只接受未压缩的 tar 层。必须解压后重新打包。

```bash
python3 fix_tar.py
```

`fix_tar.py` 内容：

```python
import tarfile, json, hashlib, io, os, gzip

SRC = "singbox-mikrotik.tar"
OUT = "singbox-mikrotik.tar"

with tarfile.open(SRC) as src:
    mf = json.loads(src.extractfile('manifest.json').read())
    config_data = src.extractfile(mf[0]['Config']).read()
    layer_compressed = src.extractfile(mf[0]['Layers'][0]).read()

layer_data = gzip.decompress(layer_compressed)

config_hash = hashlib.sha256(config_data).hexdigest()
layer_hash = hashlib.sha256(layer_data).hexdigest()

manifest = [{"Config": f"blobs/sha256/{config_hash}",
             "RepoTags": ["singbox:latest"],
             "Layers": [f"blobs/sha256/{layer_hash}"],
             "LayerSources": {f"sha256:{layer_hash}": {
                 "mediaType": "application/vnd.oci.image.layer.v1.tar",
                 "size": len(layer_data),
                 "digest": f"sha256:{layer_hash}"}}}]

oci_mf = {"schemaVersion": 2,
           "mediaType": "application/vnd.oci.image.manifest.v1+json",
           "config": {"mediaType": "application/vnd.oci.image.config.v1+json",
                      "digest": f"sha256:{config_hash}", "size": len(config_data)},
           "layers": [{"mediaType": "application/vnd.oci.image.layer.v1.tar",
                       "digest": f"sha256:{layer_hash}", "size": len(layer_data)}]}
oci_mf_bytes = json.dumps(oci_mf).encode()
oci_mf_hash = hashlib.sha256(oci_mf_bytes).hexdigest()

index = {"schemaVersion": 2,
         "mediaType": "application/vnd.oci.image.index.v1+json",
         "manifests": [{"mediaType": "application/vnd.oci.image.manifest.v1+json",
                        "digest": f"sha256:{oci_mf_hash}", "size": len(oci_mf_bytes),
                        "annotations": {"io.containerd.image.name": "docker.io/library/singbox:latest",
                                        "org.opencontainers.image.ref.name": "latest"}}]}

def add(tar, name, data):
    i = tarfile.TarInfo(name); i.size = len(data); tar.addfile(i, io.BytesIO(data))
def add_dir(tar, name):
    i = tarfile.TarInfo(name); i.type = tarfile.DIRTYPE; i.mode = 0o755; tar.addfile(i)

with tarfile.open(OUT, 'w') as o:
    add_dir(o, 'blobs'); add_dir(o, 'blobs/sha256')
    add(o, f'blobs/sha256/{layer_hash}', layer_data)
    add(o, f'blobs/sha256/{config_hash}', config_data)
    add(o, f'blobs/sha256/{oci_mf_hash}', oci_mf_bytes)
    add(o, 'manifest.json', json.dumps(manifest).encode())
    add(o, 'index.json', json.dumps(index).encode())
    add(o, 'oci-layout', json.dumps({"imageLayoutVersion":"1.0.0"}).encode())
    add(o, 'repositories', json.dumps({"singbox":{"latest":layer_hash}}).encode())

print(f'Done: {os.path.getsize(OUT)/1024/1024:.1f} MB')
```

## MikroTik 兼容 tar 格式要求

| 项目 | 要求 |
|------|------|
| 层文件位置 | `blobs/sha256/<hash>`（OCI 布局） |
| 层文件格式 | **未压缩 tar**（magic = `ustar`），不能是 gzip/zstd |
| manifest.json | 必须包含 `LayerSources` 字段 |
| 元数据文件 | `manifest.json` + `index.json` + `oci-layout` + `repositories` |
