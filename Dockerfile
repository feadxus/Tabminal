FROM node:latest

# 自动注入构建目标架构 (amd64 / arm64)
ARG TARGETARCH

WORKDIR /app

ARG TABMINAL_NPM_SPEC=tabminal

# Install cloudflared
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# Install Tabminal from npm
RUN npm install -g "${TABMINAL_NPM_SPEC}" --unsafe-perm --allow-root

# Expose the default port
EXPOSE 9846

# Set the entrypoint to the Tabminal CLI
ENTRYPOINT ["tabminal"]

# Default command (can be overridden)
CMD ["--help"]
