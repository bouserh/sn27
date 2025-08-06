###############################################################################
# Base image: CUDA 12 runtime on Ubuntu 22.04 (Salad)
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

###############################################################################
# 1 · Minimal OS tooling  (note: **git** added back)
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 2 · Python venv
###############################################################################
WORKDIR /miner
RUN python3 -m venv venv

###############################################################################
# 3 · Python packages
###############################################################################
RUN . venv/bin/activate && \
    # Torch CPU wheel (GPU picked up at runtime)
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    # Bittensor core
    pip install --no-cache-dir "bittensor>=9.8,<10" && \
    # Miner code (sn27) + compute backend (ni-compute) from one repo
    pip install --no-cache-dir \
        "sn27       @ git+https://github.com/neuralinternet/SN27.git@main#egg=sn27&subdirectory=neurons" \
        "ni-compute @ git+https://github.com/neuralinternet/SN27.git@main#egg=ni-compute&subdirectory=compute"

###############################################################################
# 4 · Prompt-free entry-point
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
