# ────────────────────────────────────────────────────────────────────────────
# 1 · Base image (CUDA runtime, Ubuntu 22.04, Salad-ready)
# ────────────────────────────────────────────────────────────────────────────
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# ────────────────────────────────────────────────────────────────────────────
# 2 · OS tooling
# ────────────────────────────────────────────────────────────────────────────
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /miner
RUN python3 -m venv venv

# ────────────────────────────────────────────────────────────────────────────
# 3 · Python deps (torch first, then BT + neuron + compute)
# ────────────────────────────────────────────────────────────────────────────
RUN . venv/bin/activate && \
    # torch CPU wheel (runtime picks up host GPUs)
    pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    # bittensor core
    pip install --no-cache-dir bittensor==9.8.* && \
    # SN-27 neuron & compute backend straight from GitHub
    pip install --no-cache-dir \
        git+https://github.com/neuralinternet/neurons.git@stable \
        git+https://github.com/neuralinternet/compute.git@stable

# ────────────────────────────────────────────────────────────────────────────
# 4 · Entry-point
# ────────────────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
