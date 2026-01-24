# syntax=docker/dockerfile:1.7

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

SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

# --- Build dependencies --------------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      curl \
      autoconf \
      automake \
      autotools-dev \
      libtool \
      gawk \
      patchutils \
      python3 \
      perl \
      build-essential \
      bison \
      flex \
      texinfo \
      gperf \
      bc \
      libmpc-dev \
      libmpfr-dev \
      libgmp-dev \
      zlib1g-dev \
      libexpat-dev; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# --- riscv-gnu-toolchain (multilib) --------------------
RUN git clone --recursive --depth 1 --shallow-submodules \
      --branch "${RISCV_GNU_TOOLCHAIN_REF}" \
      https://github.com/riscv-collab/riscv-gnu-toolchain /tmp/riscv-gnu-toolchain

WORKDIR /tmp/riscv-gnu-toolchain
RUN ./configure --prefix="${RISCV}" --enable-multilib
RUN make -j"$(nproc)"

WORKDIR /tmp
RUN rm -rf /tmp/riscv-gnu-toolchain

# --- riscv32-unknown-elf-* alias -----------------------
RUN tools=(gcc g++ as ld objcopy objdump ar ranlib nm strip size readelf); \
    for t in "${tools[@]}"; do \
      src="${RISCV}/bin/riscv64-unknown-elf-${t}"; \
      dst="${RISCV}/bin/riscv32-unknown-elf-${t}"; \
      if [[ -x "${src}" ]]; then \
        ln -sf "riscv64-unknown-elf-${t}" "${dst}"; \
      fi; \
    done

# --- riscv-tests ---------------------------------------
# clone
RUN git clone --recursive --depth 1 --shallow-submodules \
      --branch "${RISCV_TESTS_REF}" \
      https://github.com/riscv-software-src/riscv-tests /tmp/riscv-tests

WORKDIR /tmp/riscv-tests

# patch link.ld start=0x0
RUN perl -0777 -i -pe 's/\.\s*=\s*0x[0-9a-fA-F_]+\s*;/\. = 0x00000000;/m' env/p/link.ld

RUN install -d "${RISCV_TESTS_ISA_DIR}"

# --- riscv-tests: build & copy RV32 --------------------
RUN make -C isa clean; \
    make -C isa -j"$(nproc)" XLEN=32 RISCV_PREFIX=riscv32-unknown-elf-; \
    find isa -maxdepth 1 -type f -name 'rv32ui-p-*' ! -name '*.dump' -exec cp -a {} "${RISCV_TESTS_ISA_DIR}/" \; ; \
    find isa -maxdepth 1 -type f -name 'rv32mi-p-*' ! -name '*.dump' -exec cp -a {} "${RISCV_TESTS_ISA_DIR}/" \; ;

# --- riscv-tests: build & copy RV64 --------------------
RUN make -C isa clean; \
    make -C isa -j"$(nproc)" XLEN=64 RISCV_PREFIX=riscv64-unknown-elf-; \
    find isa -maxdepth 1 -type f -name 'rv64ui-p-*' ! -name '*.dump' -exec cp -a {} "${RISCV_TESTS_ISA_DIR}/" \; ; \
    find isa -maxdepth 1 -type f -name 'rv64mi-p-*' ! -name '*.dump' -exec cp -a {} "${RISCV_TESTS_ISA_DIR}/" \; ;

WORKDIR /tmp
RUN rm -rf /tmp/riscv-tests


############################
# runtime
############################
FROM ubuntu:24.04 AS runtime
ARG DEBIAN_FRONTEND=noninteractive

ARG RISCV=/opt/riscv
ARG RISCV_TESTS_INSTALL=/opt/riscv-tests-install

ENV RISCV="${RISCV}"
ENV PATH="${RISCV}/bin:${PATH}"

SHELL ["/bin/bash", "-eu", "-o", "pipefail", "-c"]

# --- Runtime dependencies ------------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      python3; \
    rm -rf /var/lib/apt/lists/*

# --- Buring artifacts from builder ---------------------
COPY --from=builder /opt/riscv /opt/riscv
COPY --from=builder ${RISCV_TESTS_INSTALL} ${RISCV_TESTS_INSTALL}

# --- Tools ---------------------------------------------
COPY bin2hex.py /usr/local/bin/bin2hex.py
COPY export_riscv_tests.sh /usr/local/bin/export_riscv_tests.sh

# on Windows (CRLF -> LF) + perms
RUN sed -i 's/\r$//' /usr/local/bin/bin2hex.py /usr/local/bin/export_riscv_tests.sh; \
    chmod +x /usr/local/bin/export_riscv_tests.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/export_riscv_tests.sh"]
