###############################################################################
# Base image: CUDA 12 runtime on Ubuntu 22.04 (Salad official - proven working)
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

###############################################################################
# 1 · System dependencies and tools
###############################################################################
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip \
        git build-essential curl ca-certificates \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

###############################################################################
# 2 · Python virtual environment
###############################################################################
WORKDIR /app
RUN python3 -m venv venv
ENV PATH="/app/venv/bin:$PATH"

###############################################################################
# 3 · Install Bittensor first
###############################################################################
RUN . venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir "bittensor>=9.8,<10"

###############################################################################
# 4 · Clone and install NI Compute with error handling
###############################################################################
ARG NICOMPUTE_REF=main
RUN git clone --depth 1 --branch ${NICOMPUTE_REF} \
        https://github.com/neuralinternet/nicompute.git /tmp/nicompute && \
    . venv/bin/activate && \
    cd /tmp/nicompute && \
    echo "📁 Repository contents:" && \
    ls -la && \
    echo "🔍 Looking for setup files:" && \
    find . -name "setup.py" -o -name "pyproject.toml" && \
    echo "📦 Installing main requirements..." && \
    pip install --no-cache-dir -r requirements.txt && \
    echo "🔍 Checking for requirements-compute.txt..." && \
    if [ -f "requirements-compute.txt" ]; then \
        echo "📦 Found requirements-compute.txt, installing..." && \
        pip install --no-cache-dir --no-deps -r requirements-compute.txt; \
    else \
        echo "⚠️  requirements-compute.txt not found, skipping..."; \
    fi && \
    echo "📦 Installing package in editable mode..." && \
    pip install --no-cache-dir -e . && \
    echo "🔍 Checking installed packages:" && \
    pip list | grep -E "(compute|nicompute|bittensor)" && \
    echo "📂 Copying files to /app..." && \
    cp -r /tmp/nicompute/* /app/ && \
    rm -rf /tmp/nicompute && \
    echo "🔍 Final /app contents:" && \
    cd /app && ls -la

###############################################################################
# 5 · Setup directories and permissions
###############################################################################
RUN mkdir -p /root/.bittensor/wallets && \
    chmod 755 /app

###############################################################################
# 6 · Copy and setup entrypoint
###############################################################################
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

###############################################################################
# 7 · Expose necessary ports
###############################################################################
EXPOSE 8091 4444

ENTRYPOINT ["/entrypoint.sh"]
