FROM node:latest

# 1️⃣ 声明架构变量(Docker Buildx 自动注入为 amd64 或 arm64)
ARG TARGETARCH

WORKDIR /app

# 1. 在 RUN 之前全局声明时区和非交互模式 
ENV TZ=Australia/Perth \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    # 添加 GitHub CLI 官方源
    && mkdir -p /usr/share/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    # 刷新软件源,统一安装所有工具
    && apt-get update && apt-get install -y --no-install-recommends \
    wget \
    pkg-config \
    libgirepository1.0-dev \
    libgirepository-2.0-dev \
    build-essential \
    gir1.2-gtk-4.0 \
    gir1.2-gtk-3.0 \
    libcairo2-dev \
    python3-dev \
    vim \
    tar \
    zsh \
    fzf \
    git \
    gh \
    # 5. 彻底清理缓存
    && rm -rf /var/lib/apt/lists/*


# 3️⃣. 配置 zsh
# 5. 彻底将 root 用户的默认 Shell 更改为 zsh (修改 /etc/passwd)
RUN chsh -s /bin/zsh root

# 6. 保留环境变量 (供 tmux、screen 或第三方 CLI 工具识别)
ENV SHELL=/bin/zsh

# 自动匹配架构下载并安装 age
RUN case "${TARGETARCH}" in \
        "amd64") AGE_ARCH="linux-amd64" ;; \
        "arm64") AGE_ARCH="linux-arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -L -s -o age.tar.gz "https://github.com/FiloSottile/age/releases/download/v1.3.2/age-v1.3.2-${AGE_ARCH}.tar.gz" && \
    tar -xzf age.tar.gz && \
    chmod +x age/age age/age-keygen && \
    mv age/age age/age-keygen /usr/local/bin/ && \
    rm -rf age.tar.gz age/


# 4️⃣ 配置 SSH 目录 / 密钥及权限(SSH 对文件权限要求极严,必须为 700 / 600)
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh

COPY sshd_config /etc/ssh/sshd_config
COPY authorized_keys /root/.ssh/authorized_keys

RUN chmod 600 /root/.ssh/authorized_keys


# 5️⃣ 从官方二进制镜像直接复制 uv (自动适配 amd64 / arm64)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
# 强行在构建阶段校验
RUN uv --version


# 6️⃣ 动态下载对应架构的 cloudflared 软件包
RUN curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}.deb" && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb


# 7️⃣ 🚀 动态判断架构并安装 VeraCrypt Console
RUN VERA_VER="1.26.29" && \
    curl -L --output veracrypt.deb "https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_${VERA_VER}/veracrypt-console-${VERA_VER}-Debian-13-${TARGETARCH}.deb" && \
    apt-get update && \
    apt-get install -y --no-install-recommends ./veracrypt.deb && \
    rm veracrypt.deb && \
    rm -rf /var/lib/apt/lists/*


# 8️⃣ 复制项目目录并提前安装 Node 依赖
COPY package*.json ./
RUN npm install


# 9️⃣ 复制剩余全部源码(包含 entrypoint.sh)
COPY . .


# 🔟 给入口脚本赋予执行权限
RUN chmod +x /app/entrypoint.sh


# 1️⃣1️⃣ 离线静态资源自动化下载与注入
RUN PUBLIC_DIR="/app/public" && \
    MODULES_DIR="${PUBLIC_DIR}/modules" && \
    mkdir -p "${MODULES_DIR}" && \
    echo "=== 开始自动化下载离线前端依赖 ===" && \
    curl -L -o "${MODULES_DIR}/xterm.js" "https://cdn.jsdelivr.net/npm/@xterm/xterm@6.1.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-fit.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.12.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-web-links.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@0.13.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-canvas.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-canvas@0.8.0-beta.48/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-search.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-search@0.17.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-progress.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-progress@0.3.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-ligatures.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-ligatures@0.11.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/dompurify.js" "https://cdn.jsdelivr.net/npm/dompurify@3.3.3/+esm" && \
    curl -L -o "${MODULES_DIR}/xterm.css" "https://cdn.jsdelivr.net/npm/@xterm/xterm@6.1.0-beta.197/css/xterm.css" && \
    npm install monaco-editor@0.55.1 && \
    cp -r node_modules/monaco-editor/min/vs "${MODULES_DIR}/vs" && \
    rm -rf node_modules/monaco-editor && \
    echo "=== 开始自动替换 public 代码中的 CDN 引用 ===" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/xterm@[^']*/+esm|/modules/xterm.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-fit@[^']*/+esm|/modules/addon-fit.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@[^']*/+esm|/modules/addon-web-links.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-canvas@[^']*/+esm|/modules/addon-canvas.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-search@[^']*/+esm|/modules/addon-search.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-progress@[^']*/+esm|/modules/addon-progress.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-ligatures@[^']*/+esm|/modules/addon-ligatures.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/dompurify@[^']*/+esm|/modules/dompurify.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|require.config({ paths: { 'vs': .*|require.config({ paths: { 'vs': '/modules/vs' }});|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/monaco-editor@[^/]*/min/vs/loader.js|/modules/vs/loader.js|g" "${PUBLIC_DIR}/index.html" && \
    sed -i "s|@import url('https://cdn.jsdelivr.net/npm/@xterm/xterm@[^']*/css/xterm.css');|@import url('/modules/xterm.css');|g" "${PUBLIC_DIR}/styles.css"


# 1️⃣2️⃣ 🐍 配置 Python 3.12 虚拟环境并使用 uv 零缓存安装依赖
ENV VIRTUAL_ENV=/root/.python-env
RUN uv python install 3.12 && \
    uv venv --python 3.12 $VIRTUAL_ENV && \
    uv pip install --no-cache \
        "requests[socks]" \
        google-api-python-client \
        google-auth-oauthlib && \
    rm -rf /root/.cache/uv


# 1️⃣3️⃣ 将 Python 虚拟环境加入 PATH
ENV PATH="$VIRTUAL_ENV/bin:$PATH"


# 1️⃣4️⃣ 编译 Node 打包工具产物
RUN npm run build && npm cache clean --force


# 1️⃣5️⃣ 全局软链接二进制文件
RUN npm link

# 暴露 SSH 12345 端口和 Tabminal 9846 端口
EXPOSE 12345 9846

# 设置脚本为容器入口
ENTRYPOINT ["/app/entrypoint.sh"]

# 默认 CMD 参数(如果 docker-compose 没有重写 command,就会用这个默认值)
CMD ["tabminal", "--host", "0.0.0.0", "--port", "9846"]
