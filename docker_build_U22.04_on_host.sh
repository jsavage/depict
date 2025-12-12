#cd ~/depict

# Create the Dockerfile
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system dependencies including webkit 4.0
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    curl \
    git \
    libwebkit2gtk-4.0-dev \
    libgtk-3-dev \
    libsoup2.4-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain stable
ENV PATH=/root/.cargo/bin:$PATH

# Install WASM target and tools
RUN rustup install nightly-2024-05-01 && \
    rustup default nightly-2024-05-01 && \
    rustup target add wasm32-unknown-unknown && \
    cargo install trunk wasm-bindgen-cli

WORKDIR /workspace

EXPOSE 8080

CMD ["bash"]  # added by js
EOF

# Build the Docker image (this will take a few minutes)
docker build -t depict-builder .

# Run container with your code mounted
docker run -it --rm -v $(pwd):/workspace -p 8080:8080 depict-builder

# Now you're inside the container with Ubuntu 22.04
# Run the build:
# ./build.sh
