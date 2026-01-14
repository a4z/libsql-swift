FROM swift:6.2.3-noble

ARG UNAME=user
ARG UID=1000
ARG GID=1000

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    clang \
    cmake \
    zip \
  && rm -rf /var/lib/apt/lists/* \
  && if ! getent group "${GID}" >/dev/null; then groupadd --gid "${GID}" "${UNAME}"; fi \
  && if ! id -u "${UNAME}" >/dev/null 2>&1; then useradd --uid "${UID}" --gid "${GID}" -m "${UNAME}"; fi

ENV HOME=/home/${UNAME}
ENV RUSTUP_HOME=/home/${UNAME}/.rustup
ENV CARGO_HOME=/home/${UNAME}/.cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

USER ${UNAME}

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal

WORKDIR /workspace

CMD ["bash"]
