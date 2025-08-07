###############################################################################
# Stage 1: Builder
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1 AS builder

# 1 · System dependencies and virtual environment
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3-venv python3-pip \
        git build-essential curl ca-certificates \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        && apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# 2 · Clone and install NI Compute
ARG NICOMPUTE_REF=main
RUN git clone --depth 1 --branch ${NICOMPUTE_REF} \
        https://github.com/neuralinternet/nicompute.git nicompute
WORKDIR /app/nicompute

# 3 · Install requirements into a temp directory
RUN python3 -m venv /tmp/venv && \
    source /tmp/venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    if [ -f "requirements-compute.txt" ]; then \
        pip install --no-cache-dir -r requirements-compute.txt; \
    fi && \
    pip install --no-cache-dir -e .

###############################################################################
# Stage 2: Final Image
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1

# 1 · System dependencies for runtime
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        && apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# 2 · Create a fresh virtual environment
RUN python3 -m venv venv
ENV PATH="/app/venv/bin:$PATH"

# 3 · Copy and install Python packages from the builder stage
COPY --from=builder /app/nicompute /app/
RUN cd /app && \
    pip install --no-cache-dir -r requirements.txt && \
    if [ -f "requirements-compute.txt" ]; then \
        pip install --no-cache-dir -r requirements-compute.txt; \
    fi && \
    pip install --no-cache-dir -e .
COPY entrypoint.sh /entrypoint.sh

# 4 · Setup
RUN mkdir -p /root/.bittensor/wallets && chmod 755 /app /root/.bittensor/wallets
RUN chmod +x /entrypoint.sh

# 5 · Expose necessary ports
EXPOSE 8091 4444

ENTRYPOINT ["/entrypoint.sh"]
