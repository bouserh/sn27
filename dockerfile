###############################################################################
# OPTION 1: Use your original working base image (RECOMMENDED)
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

## Alternative Option 2: Use official NVIDIA CUDA image (uncomment to use)
## FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

###############################################################################
# 1 · System dependencies and tools
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip \
        git build-essential curl ca-certificates \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 2 · Python virtual environment
###############################################################################
WORKDIR /app
RUN python3 -m venv venv
ENV PATH="/app/venv/bin:$PATH"

###############################################################################
# 3 · Install Bittensor first
###############################################################################
RUN . venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir "bittensor>=9.8,<10"

###############################################################################
# 4 · Clone and install NI Compute
###############################################################################
ARG NICOMPUTE_REF=main
RUN git clone --depth 1 --branch ${NICOMPUTE_REF} \
        https://github.com/neuralinternet/ni-compute.git /tmp/ni-compute && \
    . venv/bin/activate && \
    cd /tmp/ni-compute && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir --no-deps -r requirements-compute.txt && \
    pip install --no-cache-dir -e . && \
    cp -r /tmp/ni-compute/* /app/ && \
    rm -rf /tmp/ni-compute

###############################################################################
# 5 · Setup directories and permissions
###############################################################################
RUN mkdir -p /root/.bittensor/wallets && \
    chmod 755 /app

###############################################################################
# 6 · Copy and setup entrypoint
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

###############################################################################
# 7 · Expose necessary ports
###############################################################################
EXPOSE 8091 4444

ENTRYPOINT ["/entrypoint.sh"]
