############################
# builder
############################
FROM ubuntu:24.04 AS builder
ARG DEBIAN_FRONTEND=noninteractive

ARG RISCV=/opt/riscv
ARG RISCV_GNU_TOOLCHAIN_REF=master
ARG RISCV_TESTS_REF=master

ARG RISCV_TESTS_INSTALL=/opt/riscv-tests-install
ARG RISCV_TESTS_ISA_DIR=${RISCV_TESTS_INSTALL}/share/riscv-tests/isa

ENV RISCV="${RISCV}"
ENV PATH="${RISCV}/bin:${PATH}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---- common build deps ----
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl git \
      autoconf automake autotools-dev libtool gawk patchutils \
      perl python3 \
      build-essential bison flex texinfo gperf bc \
      libmpc-dev libmpfr-dev libgmp-dev zlib1g-dev libexpat-dev; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# ---- riscv-gnu-toolchain (multilib) ----
RUN set -eux; \
    git clone --recursive --depth 1 --shallow-submodules \
      --branch "${RISCV_GNU_TOOLCHAIN_REF}" \
      https://github.com/riscv-collab/riscv-gnu-toolchain /tmp/riscv-gnu-toolchain; \
    cd /tmp/riscv-gnu-toolchain; \
    ./configure --prefix="${RISCV}" --enable-multilib; \
    make -j"$(nproc)"; \
    rm -rf /tmp/riscv-gnu-toolchain

# ---- riscv32-unknown-elf-* alias
RUN set -eux; \
    tools=(gcc g++ as ld objcopy objdump ar ranlib nm strip size readelf); \
    for t in "${tools[@]}"; do \
      src="${RISCV}/bin/riscv64-unknown-elf-${t}"; \
      dst="${RISCV}/bin/riscv32-unknown-elf-${t}"; \
      if [[ -x "${src}" ]]; then ln -sf "riscv64-unknown-elf-${t}" "${dst}"; fi; \
    done

# ---- riscv-tests: build isa only (RV32, env/p, start=0x0) ----
RUN set -eux; \
    git clone --recursive --depth 1 --shallow-submodules \
      --branch "${RISCV_TESTS_REF}" \
      https://github.com/riscv-software-src/riscv-tests /tmp/riscv-tests; \
    \
    cd /tmp/riscv-tests; \
    # env/p/link.ld の先頭を 0x00000000 にする
    perl -0777 -i -pe 's/\.\s*=\s*0x[0-9a-fA-F_]+\s*;/\. = 0x00000000;/m' env/p/link.ld; \
    \
    make -C isa clean; \
    make -C isa -j"$(nproc)" XLEN=32 RISCV_PREFIX=riscv32-unknown-elf-; \
    \
    install -d "${RISCV_TESTS_ISA_DIR}"; \
    cp -a isa/rv32ui-p-* "${RISCV_TESTS_ISA_DIR}/"; \
    cp -a isa/rv32mi-p-* "${RISCV_TESTS_ISA_DIR}/"; \
    \
    rm -rf /tmp/riscv-tests

############################
# runtime
############################
FROM ubuntu:24.04 AS runtime
ARG DEBIAN_FRONTEND=noninteractive
ARG RISCV=/opt/riscv
ARG RISCV_TESTS_INSTALL=/opt/riscv-tests-install

ENV RISCV="${RISCV}"
ENV PATH="${RISCV}/bin:${PATH}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      python3; \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/riscv /opt/riscv
COPY --from=builder ${RISCV_TESTS_INSTALL} ${RISCV_TESTS_INSTALL}

# tools
COPY bin2hex.py /usr/local/bin/bin2hex.py
COPY export_riscv_tests.sh /usr/local/bin/export_riscv_tests.sh

# on Windows (CRLF -> LF)
RUN sed -i 's/\r$//' /usr/local/bin/bin2hex.py /usr/local/bin/export_riscv_tests.sh \
 && chmod +x /usr/local/bin/export_riscv_tests.sh

RUN chmod +x /usr/local/bin/export_riscv_tests.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/export_riscv_tests.sh"]
