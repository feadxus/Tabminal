FROM node:latest

# 1. 必须在此处声明 TARGETARCH，Docker Buildx 会自动将其填充为 amd64 或 arm64
ARG TARGETARCH

WORKDIR /app

ARG TABMINAL_NPM_SPEC=tabminal

# 2. 动态下载对应架构的 cloudflared 软件包 (cloudflared-linux-amd64.deb / cloudflared-linux-arm64.deb)
RUN curl -L --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${TARGETARCH}.deb" && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 3. 移除已被新版 npm 废弃的标志，避免 warning
RUN npm install -g "${TABMINAL_NPM_SPEC}"

# Expose the default port
EXPOSE 9846

# Set the entrypoint to the Tabminal CLI
ENTRYPOINT ["tabminal"]

# Default command
CMD ["--help"]
