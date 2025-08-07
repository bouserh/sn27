###############################################################################
# Stage 1: Builder
###############################################################################
[cite_start]FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1 AS builder [cite: 1]

# 1 · System dependencies
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3-venv python3-pip \
        git build-essential curl ca-certificates \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        [cite_start]&& apt-get clean && rm -rf /var/lib/apt/lists/* [cite: 1]

# 2 · Python virtual environment and Bittensor installation
[cite_start]WORKDIR /tmp/app [cite: 1]
[cite_start]RUN python3 -m venv venv [cite: 1]
[cite_start]ENV PATH="/tmp/app/venv/bin:$PATH" [cite: 1]
RUN pip install --no-cache-dir --upgrade pip && \
    [cite_start]pip install --no-cache-dir "bittensor>=9.8,<10" [cite: 1]

# 3 · Clone and install NI Compute
[cite_start]ARG NICOMPUTE_REF=main [cite: 1]
RUN git clone --depth 1 --branch ${NICOMPUTE_REF} \
        [cite_start]https://github.com/neuralinternet/nicompute.git nicompute [cite: 1]
[cite_start]WORKDIR /tmp/app/nicompute [cite: 1]
RUN pip install --no-cache-dir -r requirements.txt && \
    if [ -f "requirements-compute.txt" ]; then \
        pip install --no-cache-dir --no-deps -r requirements-compute.txt; \
    fi && \
    [cite_start]pip install --no-cache-dir -e . [cite: 1]

###############################################################################
# Stage 2: Final Image
###############################################################################
[cite_start]FROM ghcr.io/saladtechnologies/recipe-base-ubuntu:0.1 [cite: 1]

# 1 · System dependencies for runtime
RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python3 python3-venv python3-pip \
        ocl-icd-libopencl1 pocl-opencl-icd \
        openssh-client \
        [cite_start]&& apt-get clean && rm -rf /var/lib/apt/lists/* [cite: 1]

# 2 · Copy assets from builder stage and local context
[cite_start]WORKDIR /app [cite: 1]
[cite_start]COPY --from=builder /tmp/app/venv /app/venv [cite: 1]
[cite_start]COPY --from=builder /tmp/app/nicompute /app [cite: 1]
COPY entrypoint.sh /entrypoint.sh

# 3 · Setup
[cite_start]RUN mkdir -p /root/.bittensor/wallets && chmod 755 /app /root/.bittensor/wallets [cite: 1]
[cite_start]ENV PATH="/app/venv/bin:$PATH" [cite: 1]
[cite_start]RUN chmod +x /entrypoint.sh [cite: 1]

# 4 · Expose necessary ports
[cite_start]EXPOSE 8091 4444 [cite: 1]

[cite_start]ENTRYPOINT ["/entrypoint.sh"] [cite: 1]
