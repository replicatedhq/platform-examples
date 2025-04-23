FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    HOME=/home/devuser

# Install common utilities and prerequisites
RUN apt-get update && apt-get install -y \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    lsof \
    make \
    netcat \
    python3 \
    python3-pip \
    python3-venv \
    software-properties-common \
    sudo \
    tar \
    unzip \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    # Create a symlink from python3 to python for compatibility
    && ln -sf /usr/bin/python3 /usr/bin/python

# Install CLI tools
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
    # Install kubectl
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/ \
    # Install Kind
    && curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 \
    && chmod +x /usr/local/bin/kind \
    # Install yq
    && wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    # Install Task
    && sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin \
    # Install Replicated CLI
    && curl -s https://api.github.com/repos/replicatedhq/replicated/releases/latest \
       | grep "browser_download_url.*linux_amd64.tar.gz" \
       | cut -d : -f 2,3 \
       | tr -d \" \
       | wget -qi - \
    && tar xf replicated_*_linux_amd64.tar.gz replicated \
    && mv replicated /usr/local/bin/ \
    && rm replicated_*_linux_amd64.tar.gz

# Install Python dependencies directly
RUN pip3 install --upgrade pip wheel setuptools \
    && pip3 install --no-cache-dir \
       "mlflow>=2.8.0,<3.0.0" \
       "numpy>=1.24.0" \
       "pandas>=2.0.0" \
       "pytest" \
       "requests" \
       "scikit-learn>=1.2.0" \
       --ignore-installed \
    || true

# Create a non-root user for better security
RUN groupadd -r devuser \
    && useradd -r -g devuser -m -s /bin/bash devuser \
    && echo "devuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/devuser

# Copy configuration files
COPY .docker/entrypoint.sh /entrypoint.sh
COPY .docker/bashrc /home/devuser/.bashrc

# Set up fallback entrypoint if needed and fix permissions
RUN if [ ! -f /entrypoint.sh ]; then \
      echo '#!/bin/bash' > /entrypoint.sh && \
      echo 'set -e' >> /entrypoint.sh && \
      echo '# Run the command' >> /entrypoint.sh && \
      echo 'exec "$@"' >> /entrypoint.sh; \
    fi \
    && chmod +x /entrypoint.sh \
    && chown devuser:devuser /home/devuser/.bashrc

# Set working directory
WORKDIR /app

# Switch to non-root user
USER devuser

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"] 