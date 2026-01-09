FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    sudo \
    jq \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install Go (required for opencode)
RUN curl -fsSL https://go.dev/dl/go1.23.4.linux-amd64.tar.gz | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:/root/go/bin:${PATH}"

# Install opencode
RUN go install github.com/opencode-ai/opencode@latest

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup component add rustfmt clippy

WORKDIR /workspace

COPY ralph.sh /usr/local/bin/ralph
RUN chmod +x /usr/local/bin/ralph

CMD ["/bin/bash"]
