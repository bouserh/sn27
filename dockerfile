###############################################################################
# Base image: CUDA 12 runtime + Ubuntu 22.04 (maintained by Salad)
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

###############################################################################
# 1 · Minimal OS tooling
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 2 · Python virtual-env
###############################################################################
WORKDIR /miner
RUN python3 -m venv venv

###############################################################################
# 3 · Python deps  (torch ▸ bittensor ▸ SN27 + compute)
###############################################################################
RUN . venv/bin/activate && \
    # Torch CPU wheel (container picks up host GPUs at runtime)
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    # Bittensor core
    pip install --no-cache-dir "bittensor>=9.8,<10" && \
    # SN27 miner package (main branch ZIP)  +  compute sub-package
    pip install --no-cache-dir \
        "SN27    @ https://github.com/neuralinternet/SN27/archive/refs/heads/main.zip" \
        "compute @ https://github.com/neuralinternet/SN27/archive/refs/heads/main.zip#subdirectory=compute"

###############################################################################
# 4 · Prompt-free entry-point (make sure this file is in your repo)
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
