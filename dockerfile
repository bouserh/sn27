###############################################################################
# Stage 1: Builder
###############################################################################
FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1 AS builder

# 1 · System dependencies
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3-venv python3-pip \
        git build-essential curl ca-certificates \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2 · Python virtual environment and Bittensor installation
WORKDIR /tmp/app
RUN python3 -m venv venv
ENV PATH="/tmp/app/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir "bittensor>=9.8,<10"

# 3 · Clone and install NI Compute
ARG NICOMPUTE_REF=main
RUN git clone --depth 1 --branch ${NICOMPUTE_REF} \
        https://github.com/neuralinternet/nicompute.git nicompute
WORKDIR /tmp/app/nicompute
RUN python3 -m venv /tmp/venv && \
    . /tmp/venv/bin/activate && \
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

# 2 · Copy assets from builder stage and local context
WORKDIR /app
COPY --from=builder /tmp/app/venv /app/venv
COPY --from=builder /tmp/app/nicompute /app
COPY entrypoint.sh /entrypoint.sh

# 3 · Setup
RUN mkdir -p /root/.bittensor/wallets && chmod 755 /app /root/.bittensor/wallets
ENV PATH="/app/venv/bin:$PATH"
RUN chmod +x /entrypoint.sh

# 4 · Expose necessary ports
EXPOSE 8091 4444

ENTRYPOINT ["/entrypoint.sh"]
