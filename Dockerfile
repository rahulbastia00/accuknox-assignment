FROM ubuntu:22.04

# Avoid interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and clean apt cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      fortune-mod \
      cowsay \
      netcat-openbsd \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Add binaries to default PATH
ENV PATH="/usr/games:${PATH}"

# Non-root user setup
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/bash -m appuser

WORKDIR /app
COPY wisecow.sh .
RUN chmod +x wisecow.sh && chown -R appuser:appgroup /app

USER 10001
EXPOSE 4499

ENTRYPOINT ["./wisecow.sh"]