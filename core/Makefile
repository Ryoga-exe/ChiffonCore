VERYL = veryl
VIVADO = vivado
DOCKER = docker

ifeq ($(OS),Windows_NT)
	# required bmatzelle.Gow
  MKDIR := mkdir.exe
	CP    := cp.exe
	CPDIR := $(CP) -r
	NPROCS = $(shell echo %NUMBER_OF_PROCESSORS%)
	HOST_PWD := $(shell cd)
else
  MKDIR := mkdir
	CP    := cp
	CPDIR := $(CP) -a
	NPROCS = $(shell grep -c 'processor' /proc/cpuinfo)
	HOST_PWD := $(shell pwd)
endif

.PHONY: build
build:
	$(VERYL) build
	$(CP) src/*.v target/

# TODO:
# .PHONY: project
# project:
# 	$(VIVADO) -mode batch -source scripts/project.tcl -nolog -nojournal

.PHONY: simulation
simulation:
	$(VIVADO) -mode gui -source scripts/simulation.tcl -nolog -nojournal

.PHONY: clean
clean:
	$(VERYL) clean
	rm -rf target
	rm -rf project .Xil *.jou *.log
	rm -rf simulation

.PHONY: riscv-tests
riscv-tests:
	$(DOCKER) build -t chiffon-riscv-tests -f tools/riscv-tests/Dockerfile tools/riscv-tests
	$(DOCKER) run --rm -v "$(HOST_PWD):/work" chiffon-riscv-tests
