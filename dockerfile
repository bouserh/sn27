###############################################################################
# 1 · Base image (Ubuntu 22.04 + NVIDIA runtime, maintained by Salad)
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

###############################################################################
# 2 · Minimal OS tooling
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 3 · Python virtual-env and core libs
###############################################################################
WORKDIR /miner
RUN python3 -m venv venv

# ── Torch CPU wheel (container picks up host GPUs at runtime) ────────────────
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4"

# ── Bittensor core ───────────────────────────────────────────────────────────
RUN . venv/bin/activate && pip install --no-cache-dir bittensor==9.8.*

###############################################################################
# 4 · SN-27 neuron + compute backend (ZIP archives → no git clone / no login)
###############################################################################
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        "neurons @ https://github.com/neuralinternet/neurons/archive/refs/heads/main.zip" \
        "compute  @ https://github.com/neuralinternet/compute/archive/refs/heads/main.zip"

###############################################################################
# 5 · Entrypoint script (prompt-free wallet handling)
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
