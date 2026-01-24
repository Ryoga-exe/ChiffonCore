############################
# builder
############################
FROM ubuntu:24.04 AS builder
ARG DEBIAN_FRONTEND=noninteractive

ARG RISCV=/opt/riscv
ARG RISCV_GNU_TOOLCHAIN_REF=master
ARG RISCV_TESTS_REF=master

ENV RISCV="${RISCV}"
ENV PATH="${RISCV}/bin:${PATH}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ---- common build deps ----
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git ca-certificates curl \
      autoconf automake autotools-dev libtool gawk patchutils \
      python3 perl \
      build-essential bison flex texinfo gperf bc \
      libmpc-dev libmpfr-dev libgmp-dev zlib1g-dev libexpat-dev; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# ---- riscv-gnu-toolchain (multilib) ----
RUN set -eux; \
    git clone --recursive --depth 1 --shallow-submodules \
      --branch "${RISCV_GNU_TOOLCHAIN_REF}" \
      https://github.com/riscv-collab/riscv-gnu-toolchain riscv-gnu-toolchain; \
    cd riscv-gnu-toolchain; \
    ./configure --prefix="${RISCV}" --enable-multilib; \
    make -j"$(nproc)"; \
    cd /; rm -rf /tmp/riscv-gnu-toolchain

# ---- riscv32-unknown-elf-* alias
RUN set -eux; \
    for tool in gcc g++ as ld objcopy objdump ar ranlib nm strip size readelf; do \
      if [ -x "${RISCV}/bin/riscv64-unknown-elf-${tool}" ]; then \
        ln -sf "riscv64-unknown-elf-${tool}" "${RISCV}/bin/riscv32-unknown-elf-${tool}"; \
      fi; \
    done

# ---- riscv-tests build (RV32 + RV64, env/p, start=0x0) ----
RUN set -eux; \
    git clone --recursive --depth 1 --shallow-submodules \
      --branch "${RISCV_TESTS_REF}" \
      https://github.com/riscv-software-src/riscv-tests /tmp/riscv-tests; \
    cd /tmp/riscv-tests; \
    # env/p/link.ld の先頭を 0x00000000 に
    perl -0777 -i -pe 's/\.\s*=\s*0x[0-9a-fA-F_]+\s*;/\. = 0x00000000;/m' env/p/link.ld; \
    \
    # RV32I(+Zicsr,+Zifencei)
    make -C isa clean; \
    make -C isa -j"$(nproc)" \
      XLEN=32 \
      RISCV_PREFIX=riscv32-unknown-elf- \
      RISCV_GCC_OPTS="-march=rv32i_zicsr_zifencei -mabi=ilp32"; \
    \
    # RV64I(+Zicsr,+Zifencei)
    make -C isa clean; \
    make -C isa -j"$(nproc)" \
      XLEN=64 \
      RISCV_PREFIX=riscv64-unknown-elf- \
      RISCV_GCC_OPTS="-march=rv64i_zicsr_zifencei -mabi=lp64"; \
    \
    install -d /opt/riscv-tests-install/share/riscv-tests/isa; \
    find isa -maxdepth 1 -type f -name 'rv32ui-p-*' ! -name '*.dump' -exec cp -a {} /opt/riscv-tests-install/share/riscv-tests/isa/ \; ; \
    find isa -maxdepth 1 -type f -name 'rv32mi-p-*' ! -name '*.dump' -exec cp -a {} /opt/riscv-tests-install/share/riscv-tests/isa/ \; ; \
    find isa -maxdepth 1 -type f -name 'rv64ui-p-*' ! -name '*.dump' -exec cp -a {} /opt/riscv-tests-install/share/riscv-tests/isa/ \; ; \
    find isa -maxdepth 1 -type f -name 'rv64mi-p-*' ! -name '*.dump' -exec cp -a {} /opt/riscv-tests-install/share/riscv-tests/isa/ \; ; \
    cd /; rm -rf /tmp/riscv-tests

############################
# runtime
############################
FROM ubuntu:24.04 AS runtime
ARG DEBIAN_FRONTEND=noninteractive
ARG RISCV=/opt/riscv

ENV RISCV="${RISCV}"
ENV PATH="${RISCV}/bin:${PATH}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates python3; \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/riscv /opt/riscv
COPY --from=builder /opt/riscv-tests-install /opt/riscv-tests-install

COPY bin2hex.py /usr/local/bin/bin2hex.py
COPY export_riscv_tests.sh /usr/local/bin/export_riscv_tests.sh

# on Windows (CRLF -> LF)
RUN sed -i 's/\r$//' /usr/local/bin/bin2hex.py /usr/local/bin/export_riscv_tests.sh \
 && chmod +x /usr/local/bin/export_riscv_tests.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/export_riscv_tests.sh"]
