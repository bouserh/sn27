###############################################################################
# Base image: CUDA 12 runtime on Ubuntu 22.04 (Salad official)
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
# 3 · Python packages
#    • torch  (CPU wheel; container sees host GPUs at runtime)
#    • bittensor ≥ 9.8
#    • sn27 miner  (project_name = sn27, subdir = neurons)
#    • ni-compute (project_name = ni-compute, subdir = compute)
###############################################################################
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    pip install --no-cache-dir "bittensor>=9.8,<10" && \
    pip install --no-cache-dir \
        "sn27 @ git+https://github.com/neuralinternet/SN27.git@main#egg=sn27&subdirectory=neurons" \
        "ni-compute @ git+https://github.com/neuralinternet/SN27.git@main#egg=ni-compute&subdirectory=compute"

###############################################################################
# 4 · Prompt-free entry-point (must exist in repo root)
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
