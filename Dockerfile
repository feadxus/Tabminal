FROM node:latest

# 必须在此处声明 TARGETARCH，Docker Buildx 会自动将其填充为 amd64 或 arm64
ARG TARGETARCH

WORKDIR /app

ARG TABMINAL_NPM_SPEC=tabminal

# 1️⃣ 动态下载对应架构的 cloudflared 软件包 (cloudflared-linux-amd64.deb / cloudflared-linux-arm64.deb)
RUN curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}.deb" && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 2️⃣ 安装全局 Tabminal
RUN npm install -g "${TABMINAL_NPM_SPEC}"

# 3️⃣ 🚀 核心: 离线化自动下载与注入步骤
RUN TABMINAL_PATH=$(node -e 'console.log(require.resolve("tabminal/package.json"))' | xargs dirname) && \
    PUBLIC_DIR="${TABMINAL_PATH}/public" && \
    MODULES_DIR="${PUBLIC_DIR}/modules" && \
    mkdir -p "${MODULES_DIR}" && \
    \
    echo "=== 开始自动化下载离线前端依赖 ===" && \
    # 1. 下载 JS 模块 (xterm & addons & dompurify)
    curl -L -o "${MODULES_DIR}/xterm.js" "https://cdn.jsdelivr.net/npm/@xterm/xterm@6.1.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-fit.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-fit@0.12.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-web-links.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@0.13.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-canvas.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-canvas@0.8.0-beta.48/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-search.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-search@0.17.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-progress.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-progress@0.3.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/addon-ligatures.js" "https://cdn.jsdelivr.net/npm/@xterm/addon-ligatures@0.11.0-beta.197/+esm" && \
    curl -L -o "${MODULES_DIR}/dompurify.js" "https://cdn.jsdelivr.net/npm/dompurify@3.3.3/+esm" && \
    \
    # 2. 下载 xterm CSS
    curl -L -o "${MODULES_DIR}/xterm.css" "https://cdn.jsdelivr.net/npm/@xterm/xterm@6.1.0-beta.197/css/xterm.css" && \
    \
    # 3. 安装并复制 monaco-editor 到 public/modules/vs
    npm install monaco-editor@0.55.1 && \
    cp -r node_modules/monaco-editor/min/vs "${MODULES_DIR}/vs" && \
    rm -rf node_modules/monaco-editor && \
    \
    echo "=== 开始自动替换 public 代码中的 CDN 引用 ===" && \
    # 替换 app.js 中的 ES Module 引用
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/xterm@[^']*/+esm|/modules/xterm.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-fit@[^']*/+esm|/modules/addon-fit.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-web-links@[^']*/+esm|/modules/addon-web-links.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-canvas@[^']*/+esm|/modules/addon-canvas.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-search@[^']*/+esm|/modules/addon-search.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-progress@[^']*/+esm|/modules/addon-progress.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/@xterm/addon-ligatures@[^']*/+esm|/modules/addon-ligatures.js|g" "${PUBLIC_DIR}/app.js" && \
    sed -i "s|https://cdn.jsdelivr.net/npm/dompurify@[^']*/+esm|/modules/dompurify.js|g" "${PUBLIC_DIR}/app.js" && \
    # 替换 app.js 中的 monaco 路径
    sed -i "s|require.config({ paths: { 'vs': .*|require.config({ paths: { 'vs': '/modules/vs' }});|g" "${PUBLIC_DIR}/app.js" && \
    \
    # 替换 index.html 中的 monaco loader
    sed -i "s|https://cdn.jsdelivr.net/npm/monaco-editor@[^/]*/min/vs/loader.js|/modules/vs/loader.js|g" "${PUBLIC_DIR}/index.html" && \
    \
    # 替换 styles.css 中的 xterm.css
    sed -i "s|@import url('https://cdn.jsdelivr.net/npm/@xterm/xterm@[^']*/css/xterm.css');|@import url('/modules/xterm.css');|g" "${PUBLIC_DIR}/styles.css"

EXPOSE 9846
ENTRYPOINT ["tabminal"]
CMD ["--help"]
