FROM python:3.12-slim-bookworm

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /app

# 1) 安装运行时 + 构建 cffi 等所需的系统依赖
RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         curl libuv1 zlib1g libjson-c5 libnl-3-200 libnl-route-3-200 \
         unzip gdb iputils-ping iproute2 \
         build-essential python3-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# 2) 把你自己打好的 wheels 拷贝进来
COPY wheels/ /wheels/

# 3) 拉 ota-provider 二进制
ARG TARGETPLATFORM
ENV chip_example_url="https://github.com/iHost-Open-Source-Project/matter-linux-ota-provider/releases/download/2025.9.0"
RUN set -x \
    && case "$TARGETPLATFORM" in \
         "linux/amd64") ARMURL=x86-64 ;; \
         "linux/arm64") ARMURL=aarch64 ;; \
         "linux/arm/v7") ARMURL=armv7 ;; \
         *) echo "unsupported $TARGETPLATFORM" >&2; exit 1 ;; \
       esac \
    && curl -Lo /usr/local/bin/chip-ota-provider-app \
        "$chip_example_url/chip-ota-provider-app-$ARMURL" \
    && chmod +x /usr/local/bin/chip-ota-provider-app

# 4) 安装 core & clusters，本地 wheels + PyPI 上拉其余依赖（包括 dacite、cffi 等）
RUN pip3 install --no-cache-dir \
        --find-links=/wheels \
        home-assistant-chip-clusters==2025.7.0 \
        home-assistant-chip-core==2025.7.0

# 5) 安装 python-matter-server[server]
ARG PYTHON_MATTER_SERVER=8.1.1
RUN pip3 install --no-cache-dir \
        --find-links=/wheels \
        "python-matter-server[server]==${PYTHON_MATTER_SERVER}"

VOLUME ["/data"]
EXPOSE 5580

ENTRYPOINT ["matter-server"]
CMD ["--storage-path", "/data", "--paa-root-cert-dir", "/data/credentials"]