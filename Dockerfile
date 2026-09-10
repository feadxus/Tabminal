FROM node:latest

# 1️⃣ 声明架构变量(Docker Buildx 自动注入为 amd64 或 arm64)
ARG TARGETARCH

WORKDIR /app

# 2️⃣ 安装原生物料编译(node-pty 必须)、Python/Gtk/Cairo 开发依赖包及 OpenSSH 服务
RUN apt-get update && apt-get install -y \
    python3 \
    python3-dev \
    build-essential \
    pkg-config \
    libgirepository1.0-dev \
    libgirepository-2.0-dev \
    gir1.2-gtk-4.0 \
    libcairo2-dev \
    gir1.2-gtk-3.0 \
    make \
    age \
    g++ \
    curl \
    direnv \
    openssh-server \
    openssh-client \
    unzip \
    zip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    lzma \
    iproute2 \
    knot \
    knot-dnsutils \
    nmap \
    netcat-openbsd \
    socat \
    tcpdump \
    tshark \
    wireguard-tools \
    iputils-ping \
    traceroute \
    mtr \
    wget \
    dnsutils \
    vim-nox \
    git \
    htop \
    screen \
    tree \
    jq \
    && rm -rf /var/lib/apt/lists/*

# 3️⃣ 配置 SSH 目录 / 密钥及权限(SSH 对文件权限要求极严,必须为 700 / 600)
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh

COPY sshd_config /etc/ssh/sshd_config
COPY authorized_keys /root/.ssh/authorized_keys

RUN chmod 600 /root/.ssh/authorized_keys

# 4️⃣ 优雅安装 uv(直接从官方镜像提取二进制,自动适配多架构)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 5️⃣ 动态下载对应架构的 cloudflared 软件包
RUN curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}.deb" && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 6️⃣ 🚀 动态判断架构并安装 VeraCrypt Console
RUN case "${TARGETARCH}" in \
        "amd64") VERA_ARCH="amd64" ;; \
        "arm64") VERA_ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    VERA_DEB="veracrypt-console-1.26.29-Debian-13-${VERA_ARCH}.deb" && \
    curl -L --output "${VERA_DEB}" "https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_1.26.29/${VERA_DEB}" && \
    dpkg -i "${VERA_DEB}" || apt-get install -f -y && \
    rm -f "${VERA_DEB}"

# 7️⃣ 复制项目目录并提前安装 Node 依赖
COPY package*.json ./
RUN npm install

# 8️⃣ 复制剩余全部源码(包含 entrypoint.sh)
COPY . .

# 9️⃣ 给入口脚本赋予执行权限
RUN chmod +x /app/entrypoint.sh

# 🔟 离线静态资源自动化下载与注入
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

# 11️⃣ 🐍 配置 Python 3.12 虚拟环境并使用 uv 零缓存安装依赖
ENV VIRTUAL_ENV=/root/.python-env
RUN uv python install 3.12 && \
    uv venv $VIRTUAL_ENV && \
    uv pip install --no-cache \
        "requests[socks]" \
        google_auth_oauthlib \
        ruamel.yaml \
        playwright \
        archivebox \
        dnspython \
        pyperclip \
        asciidoc \
        httpstat \
        aiofiles \
        watchdog \
        schedule \
        PySocks \
        pyyaml \
        geoip2 \
        yt-dlp \
        pytest \
        pandas \
        scapy \
        "litellm[proxy]" \
        huggingface_hub \
        hf_transfer \
        mitmproxy \
        httpx \
        google-api-python-client \
        google-auth-oauthlib \
        bcc \
        browser-use \
        PyGObject && \
    rm -rf /root/.cache/uv

# 1️⃣2️⃣ 将 Python 虚拟环境加入 PATH
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# 1️⃣3️⃣ 编译 Node 打包工具产物
RUN npm run build && npm cache clean --force

# 1️⃣4️⃣ 全局软链接二进制文件
RUN npm link

# 暴露 SSH 12345 端口和 Tabminal 9846 端口
EXPOSE 12345 9846

# 设置脚本为容器入口
ENTRYPOINT ["/app/entrypoint.sh"]

# 默认 CMD 参数(如果 docker-compose 没有重写 command,就会用这个默认值)
CMD ["tabminal", "--host", "0.0.0.0", "--port", "9846"]
