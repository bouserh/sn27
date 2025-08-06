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
# 2 · Python venv
###############################################################################
WORKDIR /miner
RUN python3 -m venv venv

###############################################################################
# 3 · Python deps
###############################################################################
# Pin one tag → reproducible builds.  Change TAG when SN27 releases a new one.
ARG SN27_TAG=v0.2.0   # ← check https://github.com/neuralinternet/SN27/releases
RUN . venv/bin/activate && \
    # Torch CPU wheel (container picks up host GPUs at runtime)
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    # Bittensor core
    pip install --no-cache-dir "bittensor>=9.8,<10" && \
    # 3a · install SN27 miner package
    pip install --no-cache-dir \
        "SN27 @ https://github.com/neuralinternet/SN27/archive/refs/tags/${SN27_TAG}.zip" && \
    # 3b · install compute module from the *same* archive, subdirectory trick
    pip install --no-cache-dir \
        "compute @ https://github.com/neuralinternet/SN27/archive/refs/tags/${SN27_TAG}.zip#subdirectory=compute"

###############################################################################
# 4 · Prompt-free entry-point (make sure this file is in your repo root)
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
