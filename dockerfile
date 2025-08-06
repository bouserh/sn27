# ────────────────────────────────────────────────────────────────────────────
# 1 · Base image (CUDA runtime, Ubuntu 22.04, nvidia-container-runtime ready)
# ────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# ────────────────────────────────────────────────────────────────────────────
# 2 · OS packages
# ────────────────────────────────────────────────────────────────────────────
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ────────────────────────────────────────────────────────────────────────────
# 3 · Python virtual-env + core deps
# ────────────────────────────────────────────────────────────────────────────
WORKDIR /miner
RUN python3 -m venv venv

# Install torch CPU wheel first (CUDA drivers come from host GPUs)
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4"

# ────────────────────────────────────────────────────────────────────────────
# 4 · Install Bittensor & SN-27 neuron & compute backend
# ────────────────────────────────────────────────────────────────────────────
RUN . venv/bin/activate && \
    pip install --no-cache-dir bittensor==9.8.* && \
    git clone --depth 1 https://github.com/neuralinternet/neurons.git /miner/neurons && \
    pip install --no-cache-dir -e /miner/neurons && \
    pip install --no-cache-dir \
        git+https://github.com/neuralinternet/compute.git@stable

# ────────────────────────────────────────────────────────────────────────────
# 5 · Entry-point script
# ────────────────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

# ────────────────────────────────────────────────────────────────────────────
# 6 · Default command
# ────────────────────────────────────────────────────────────────────────────
ENTRYPOINT ["/entrypoint.sh"]
