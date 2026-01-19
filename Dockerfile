FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    git \
    ca-certificates \
    cmake \
    # Dependencies for desktop application (GTK/glib)
    libgtk-3-dev \
    libglib2.0-dev \
    libsoup2.4-dev \
    libjavascriptcoregtk-4.0-dev \
    libwebkit2gtk-4.0-dev \
    # for flutter
    unzip \
    zip \
    xz-utils \
#    ca-certificates \
#    build-essential \
    clang \
#    cmake \
    ninja-build \
#    pkg-config \
#    libssl-dev \
#    libgtk-3-dev \
    liblzma-dev \
#    libstdc++-12-dev \
    python3 \
    python3-pip \
    libglu1-mesa \
    libpulse-dev \
    nano \
    && rm -rf /var/lib/apt/lists/*


# Install Rust with a modern nightly that supports edition2024
# Using a specific date for reproducibility
ENV RUST_NIGHTLY_DATE=2024-11-30
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

# ---- Flutter SDK ----
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME \
    && flutter channel stable \
    && flutter upgrade

# Pre-cache artifacts to avoid CI delays
RUN flutter doctor -v
RUN flutter precache --linux

# Disable analytics (important for CI)
RUN flutter config --no-analytics
# ----- End of flutter SDX ----


# Set working directory
WORKDIR /workspace

# Verify installations
RUN rustc --version && \
    cargo --version && \
    trunk --version && \
    wasm-bindgen --version && \
    flutter --version && \
    dart --version

# Default command
CMD ["/bin/bash"]
ENV RUST_NIGHTLY_DATE=2024-11-30
