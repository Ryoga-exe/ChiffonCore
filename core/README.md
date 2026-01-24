# ChiffonCore - core

CPU core built with Veryl and targeting Ultra96V2.

## Prerequisites

- **Veryl**: Install from https://veryl-lang.org/install
- **Xilinx Vivado** 2024.2 or later
- **Make** utility on your PATH

## Build

```shell
make build
```

## Create a simulation project and open

```shell
make simulation
```

## Create riscv-tests hex

```shell
make riscv-tests
```

## Cleaning up

```shell
make clean
```

## Run all riscv-tests

```shell
python3 tools/riscv-tests/run.py

# to specify prefix (default: rv32ui-p-)
python3 tools/riscv-tests/run.py --prefix
```
