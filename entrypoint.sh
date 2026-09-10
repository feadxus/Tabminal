#!/bin/bash
set -e

# 1️⃣. 确保 sshd 运行所需的目录存在
mkdir -p /var/run/sshd

# 2️⃣. 自动生成 SSH 主机密钥(如果尚不存在)
ssh-keygen -A 2>/dev/null || true

# 3️⃣. 确保 .ssh 目录和 authorized_keys 权限正确
chmod 700 /root/.ssh 2>/dev/null || true
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true

# 4️⃣. 后台启动 OpenSSH 服务
/usr/sbin/sshd
echo "=== OpenSSH 服务已在 22 端口后台启动 ==="

# 5️⃣. 判断传进来的第一个参数:
# 如果传入的第一个参数是以 "-" 开头的(比如 Docker Compose 里的 --accept-terms ...)
# 或者第一个参数不是 tabminal 命令本身,我们就把 "tabminal" 自动拼在最前面!
if [ "${1#-}" != "$1" ]; then
    set -- tabminal "$@"
fi

# 6️⃣. 执行主进程命令(继承 PID 1,确保能正确接收停止信号)
echo "=== 正在启动 Tabminal: $@ ==="
exec "$@"
