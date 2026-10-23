# Agent CI : Maven 17 + Docker CLI + SSH + curl
FROM maven:3.9-eclipse-temurin-17

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      openssh-client \
      git \
 && curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.1.1.tgz \
    | tar -xz --strip-components=1 -C /usr/local/bin docker/docker \
 && chmod +x /usr/local/bin/docker \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
