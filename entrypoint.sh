#!/bin/bash
set -e

# 1. 确保 sshd 所需的运行目录存在
mkdir -p /var/run/sshd

# 2. 如果缺少 SSH 主机密钥，自动重新生成(防止首次启动失败)
ssh-keygen -A 2>/dev/null || true

# 3. 后台启动 OpenSSH Server
/usr/sbin/sshd

# 4. 打印提示信息
echo "=== SSH 服务已在端口 22 启动 ==="

# 5. 执行传给容器的默认命令 ((Tabminal)
exec "$@"
