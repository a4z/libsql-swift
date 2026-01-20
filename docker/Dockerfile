FROM swift:6.2.3-noble

# swift:noble has user 'ubuntu' with UID/GID 1000
ENV HOME=/home/ubuntu
ENV RUSTUP_HOME=/home/ubuntu/.rustup
ENV CARGO_HOME=/home/ubuntu/.cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    clang \
    cmake \
    zip

RUN rm -rf /var/lib/apt/lists/*

USER ubuntu

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal

WORKDIR /workspace

CMD ["bash"]
