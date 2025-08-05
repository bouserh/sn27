# ---- Salad base -------------------------------------------------------
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# ---- OS tooling -------------------------------------------------------
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip git build-essential curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /miner
RUN python3 -m venv venv

# ---- 1 · Install Torch 2.1.2 CPU wheel (matches bittensor 6.4) -------
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cpu \
      torch==2.1.2+cpu

# ---- 2 · Install remaining deps --------------------------------------
COPY requirements.txt .
RUN . venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# ---- Clone Subnet-27 neuron ------------------------------------------
RUN git clone --depth 1 https://github.com/neuralinternet/neurons.git /miner/neurons

# ---- Entrypoint -------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"
ENTRYPOINT ["/entrypoint.sh"]
