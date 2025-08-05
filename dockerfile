# ---- Salad base image (Ubuntu 22.04, Python 3.11) -------------------
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# ---- System tooling --------------------------------------------------
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- Virtual-env -----------------------------------------------------
WORKDIR /miner
RUN python3 -m venv venv

# ---- 1 · Install Torch CPU wheel (fits cp311) ------------------------
#      Torch 2.3.x satisfies bittensor (<2.4) and has ready-made CPU wheels.
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "torch>=2.3,<2.4"

# ---- 2 · Remaining Python deps --------------------------------------
COPY requirements.txt .
RUN . venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# ---- 3 · Clone Subnet-27 miner (public repo) -------------------------
RUN git clone --depth 1 https://github.com/neuralinternet/SN27.git /miner/neurons

# ---- Entrypoint ------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"
ENTRYPOINT ["/entrypoint.sh"]
