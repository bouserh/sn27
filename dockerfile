FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1  # CUDA 12, Ubuntu 22.04

# ── OS tooling ──────────────────────────────────────────────────────────────
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /miner
RUN python3 -m venv venv

# ── Python deps ─────────────────────────────────────────────────────────────
RUN . venv/bin/activate && \
    # torch CPU wheel (GPU picked up at runtime)
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    # Bittensor core
    pip install --no-cache-dir "bittensor>=9.8,<10" && \
    # SN27 miner + shared compute backend
    pip install --no-cache-dir \
        git+https://github.com/neuralinternet/SN27.git@main \
        git+https://github.com/neuralinternet/compute.git@main

# ── Entry-point (your prompt-free script) ───────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
