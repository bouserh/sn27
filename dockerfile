FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# --- OS tooling (git required) ------------------------------------------------
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /miner
RUN python3 -m venv venv

# --- Python deps --------------------------------------------------------------
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4" && \
    pip install --no-cache-dir "bittensor>=9.8,<10"

# --- Clone SN27 once and install sub-dirs in editable mode --------------------
ARG SN27_REF=main          # change to a tag/commit if you prefer
RUN git clone --depth 1 --branch ${SN27_REF} \
      https://github.com/neuralinternet/SN27.git /tmp/SN27 && \
    . venv/bin/activate && \
    pip install --no-cache-dir -e /tmp/SN27/neurons      && \   # miner code
    pip install --no-cache-dir -e /tmp/SN27/compute          # compute backend

# --- Entry-point --------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"
ENTRYPOINT ["/entrypoint.sh"]
