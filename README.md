# gost-server-kit

极简的 GOST 服务端部署工具，用于快速布置 `ws/wss/mws/mwss` 隧道，把入口流量转发到本机已有的协议端口，例如 `127.0.0.1:8388`。

## 用途

适合当前这类场景：

- 已有本机 `SS` / 其它 TCP 服务在监听
- 只想快速挂一层 GOST 隧道入口
- 希望用 `systemd` 托管
- 不想手写长命令或 YAML

## 目录

- `deploy-gost-server.sh`
  - 主部署脚本
- `gost-server.service.tpl`
  - systemd 模板

## 快速开始

1. 直接运行脚本：

```bash
sudo bash deploy-gost-server.sh
```

2. 按提示输入：

- 实例名
- 传输类型
- 监听地址与端口
- 本机目标地址与端口
- `ws/mws/wss/mwss` 时输入 `WS path`
- TLS 类时输入证书路径

3. 查看状态：

```bash
systemctl status gost-server-<INSTANCE>.service
journalctl -u gost-server-<INSTANCE>.service -f
```

## 支持的 TRANSPORT

- `ws`
- `wss`
- `mws`
- `mwss`
- `tls`
- `mtls`

当前最推荐直接使用：

- `ws`
- `wss`
- `mws`
- `mwss`

## 生成结果

脚本会生成：

- `/etc/gost-server/<INSTANCE>.yaml`
- `/etc/systemd/system/gost-server-<INSTANCE>.service`

## 设计约定

- 服务端固定做“入口监听 -> 转发到本机目标端口”
- 默认目标地址：`127.0.0.1`
- `ws/mws/wss/mwss` 默认路径：`/ws`
- `wss/mwss/tls/mtls` 需要证书文件

## 常用操作

重启：

```bash
sudo systemctl restart gost-server-<INSTANCE>.service
```

停止：

```bash
sudo systemctl stop gost-server-<INSTANCE>.service
```

删除：

```bash
sudo systemctl disable --now gost-server-<INSTANCE>.service
sudo rm -f /etc/systemd/system/gost-server-<INSTANCE>.service
sudo rm -f /etc/gost-server/<INSTANCE>.yaml
sudo systemctl daemon-reload
```
