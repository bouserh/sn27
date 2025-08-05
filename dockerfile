# ---- Salad base -------------------------------------------------------
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# ---- add Python 3.10 (cp310 wheels available for torch 2.1.x) --------
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3.10 python3.10-venv && \
    ln -sf /usr/bin/python3.10 /usr/local/bin/python

WORKDIR /miner
RUN python -m venv venv

# torch 2.1.2 CPU wheel (cp310) ----------------------------------------
RUN . venv/bin/activate && \
    pip install --no-cache-dir \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        torch==2.1.2

# remaining deps --------------------------------------------------------
COPY requirements.txt .
RUN . venv/bin/activate && \
    pip install --no-cache-dir -r requirements.txt

# clone Subnet-27 neuron -----------------------------------------------
RUN git clone --depth 1 https://github.com/neuralinternet/neurons.git /miner/neurons

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV PATH="/miner/venv/bin:$PATH"
ENTRYPOINT ["/entrypoint.sh"]
