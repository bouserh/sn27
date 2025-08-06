###############################################################################
# Base image: CUDA 12 runtime + Ubuntu 22.04, maintained by Salad
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

###############################################################################
# 1 · Minimal OS tooling
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 2 · Python virtual-env and core libs
###############################################################################
WORKDIR /miner
RUN python3 -m venv venv

RUN . venv/bin/activate && \
    # torch CPU wheel (GPU picked up at runtime)
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    # Bittensor core
    pip install --no-cache-dir "bittensor>=9.8,<10" && \
    # SN27 miner + compute backend (head of main; swap for tag when available)
    pip install --no-cache-dir \
        git+https://github.com/neuralinternet/SN27.git@main \
        git+https://github.com/neuralinternet/compute.git@main

###############################################################################
# 3 · Entry-point (prompt-free wallet script)
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
