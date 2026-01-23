FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive

# ---- deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates curl \
    autoconf automake autotools-dev libtool gawk patchutils \
    python3 \
    build-essential bison flex texinfo gperf bc \
    libmpc-dev libmpfr-dev libgmp-dev zlib1g-dev libexpat-dev \
 && rm -rf /var/lib/apt/lists/*

# ---- riscv-gnu-toolchain (multilib) ----
# ここは "将来RV64も" を見越して multilib を有効にしておく（rv32/rv64 を -march/-mabi で切替可能）
ENV RISCV=/opt/riscv
ENV PATH=${RISCV}/bin:${PATH}

RUN git clone --recursive https://github.com/riscv-collab/riscv-gnu-toolchain /tmp/riscv-gnu-toolchain \
 && cd /tmp/riscv-gnu-toolchain \
 && ./configure --prefix=${RISCV} --enable-multilib \
 && make -j"$(nproc)" \
 && rm -rf /tmp/riscv-gnu-toolchain

# ---- riscv-tests build (RV32, env/p, start=0x0) ----
RUN git clone https://github.com/riscv-software-src/riscv-tests /opt/riscv-tests \
 && cd /opt/riscv-tests \
 && git submodule update --init --recursive \
 && autoconf \
 && ./configure --prefix=/opt/riscv-tests-install \
 # env/p/link.ld の先頭を 0x00000000 にする
 && sed -i -E 's/^[[:space:]]*\.[[:space:]]*=[[:space:]]*0x[0-9a-fA-F]+[[:space:]]*;/  . = 0x00000000;/' env/p/link.ld \
 # toolchain prefix を riscv64 に
 && make -j"$(nproc)" XLEN=32 RISCV_PREFIX=riscv64-unknown-elf isa \
 && make XLEN=32 RISCV_PREFIX=riscv64-unknown-elf install-isa

# tools
COPY bin2hex.py /usr/local/bin/bin2hex.py
COPY export_riscv_tests.sh /usr/local/bin/export_riscv_tests.sh
RUN chmod +x /usr/local/bin/export_riscv_tests.sh

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/export_riscv_tests.sh"]
