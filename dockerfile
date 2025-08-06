###############################################################################
# Base image: CUDA 12 runtime on Ubuntu 22.04 (Salad official)
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

###############################################################################
# 1 · Minimal OS tooling  (git is required for editable installs)
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 2 · Python virtual-env
###############################################################################
WORKDIR /miner
RUN python3 -m venv venv

###############################################################################
# 3 · Core Python deps: torch ▸ bittensor
###############################################################################
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    pip install --no-cache-dir "bittensor>=9.8,<10"

###############################################################################
# 4 · Clone SN27 once and install both sub-packages in editable mode
###############################################################################
ARG SN27_REF=main           # switch to a tag/commit if you prefer
RUN git clone --depth 1 --branch ${SN27_REF} \
        https://github.com/neuralinternet/SN27.git /tmp/SN27 && \
    . venv/bin/activate && \
    # miner code
    pip install --no-cache-dir -e /tmp/SN27/neurons && \
    # compute backend
    pip install --no-cache-dir -e /tmp/SN27/compute

###############################################################################
# 5 · Prompt-free entry-point (make sure entrypoint.sh exists in repo root)
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"

ENTRYPOINT ["/entrypoint.sh"]
