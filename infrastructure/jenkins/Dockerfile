# ==========================================
# KerjaDekat — Jenkins CI Server
# Needs Docker socket to build images
# Needs Git + SSH to push to GitOps repo
# DOES NOT need kubectl (ArgoCD handles deploy)
# ==========================================
FROM jenkins/jenkins:lts-jdk17

USER root

# Install tools
RUN apt-get update && \
    apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    jq \
    wget \
    make \
    git \
    lsb-release

# Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli docker-buildx-plugin

# Install yq (for modifying GitOps YAMLs)
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# Go back to Jenkins user
USER jenkins

# Pre-install plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
