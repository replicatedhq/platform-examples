FROM --platform=$BUILDPLATFORM ubuntu:24.04 AS build

ARG TARGETOS
ARG TARGETARCH

# Tool versions
ARG REPLICATED_VERSION=0.101.1
ARG TASK_VERSION=3.43.2
ARG KUBECTL_VERSION=1.30.1
ARG HELM_VERSION=3.17.3
ARG HELMFILE_VERSION=0.171.0
ARG YQ_VERSION=4.45.1

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    yq \
    gpg \
    && rm -rf /var/lib/apt/lists/*

# Install the Google Cloud tools following the instructions here: https://cloud.google.com/sdk/docs/install#deb
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update \
    && apt-get install google-cloud-cli -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tools

# TODO: use checksums to verify the downloaded files

# TODO: Use this to build for different platforms
RUN echo "======================================================="
RUN echo "Building for TARGET PLATFORM: ${TARGETOS}_${TARGETARCH}"
RUN echo "======================================================="

# Download and extract the replicated binary
RUN curl -L -o replicated.tar.gz https://github.com/replicatedhq/replicated/releases/download/v${REPLICATED_VERSION}/replicated_${REPLICATED_VERSION}_linux_amd64.tar.gz \
    && tar -xzf replicated.tar.gz \
    && rm -f replicated.tar.gz LICENSE README.md

# Download and extract the task binary
RUN curl -L -o task.tar.gz https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_${TARGETOS}_${TARGETARCH}.tar.gz \
    && tar -xzf task.tar.gz \
    && rm -rf task.tar.gz LICENSE README.md completion/

# Download and extract the kubectl binary
RUN curl -L -o kubectl https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl \
    && chmod +x kubectl

# Download and extract the helm binary
RUN curl -L -o helm.tar.gz https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz \
    && tar -xzf helm.tar.gz \
    && mv ${TARGETOS}-${TARGETARCH}/helm . \
    && rm -rf ${TARGETOS}-${TARGETARCH} helm.tar.gz

# Download helmfile binary
RUN curl -vL -o helmfile.tar.gz https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz \
    && tar -xzf helmfile.tar.gz \
    && rm -f helmfile.tar.gz

# Download and extract the yq binary
RUN curl -L -o yq https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${TARGETOS}_${TARGETARCH} \
    && chmod +x yq

WORKDIR /app

ENV PATH="/tools:${PATH}"
