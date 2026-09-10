FROM node:latest

# 1️⃣ 声明架构变量 
ARG TARGETARCH

WORKDIR /app

# 2️⃣ 安装原生物料编译所需的系统依赖（node-pty 必须）
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 3️⃣ 动态下载对应架构的 cloudflared 软件包
RUN curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}.deb" && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 4️⃣ 复制项目名录并提前安装依赖
COPY package*.json ./
RUN npm install

# 5️⃣ 复制剩余全部源码
COPY . .

# 6️⃣ 🚀 核心：离线静态资源自动化下载与注入（调整到 build 之前，确保被打包工具捕获）
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

# 7️⃣ 编译打包（把已经替换好本地引用的源码，完好地锁进发布目录）
RUN npm run build

# 8️⃣ 全局软链接二进制文件
RUN npm link

# Expose the default port
EXPOSE 9846

# Set the entrypoint to the Tabminal CLI
ENTRYPOINT ["tabminal"]

# Default command (can be overridden)
CMD ["--help"]
