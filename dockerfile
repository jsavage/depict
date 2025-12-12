FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    git \
    ca-certificates \
    # Dependencies for desktop application (GTK/glib)
    libgtk-3-dev \
    libglib2.0-dev \
    libsoup2.4-dev \
    libjavascriptcoregtk-4.0-dev \
    libwebkit2gtk-4.0-dev \
    # Additional useful tools
    && rm -rf /var/lib/apt/lists/*

# Install Rust with a modern nightly that supports edition2024
# Using a specific date for reproducibility
ENV RUST_NIGHTLY_DATE=2024-12-01
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    --default-toolchain nightly-${RUST_NIGHTLY_DATE} \
    --profile minimal \
    --component rustfmt,clippy

ENV PATH="/root/.cargo/bin:${PATH}"

# Add wasm target
RUN rustup target add wasm32-unknown-unknown

# Install trunk at a specific version for reproducibility
# Using version that works with modern Rust but is stable
RUN cargo install trunk --version 0.21.4 --locked

# Install wasm-bindgen-cli matching the version in your Cargo.lock
# This prevents version mismatches
RUN cargo install wasm-bindgen-cli --version 0.2.95 --locked

# Set working directory
WORKDIR /workspace

# Verify installations
RUN rustc --version && \
    cargo --version && \
    trunk --version && \
    wasm-bindgen --version

# Default command
CMD ["/bin/bash"]