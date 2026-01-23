VERYL = veryl
VIVADO = vivado

ifeq ($(OS),Windows_NT)
	# required bmatzelle.Gow
  MKDIR := mkdir.exe
	CP    := cp.exe
	CPDIR := $(CP) -r
	NPROCS = $(shell echo %NUMBER_OF_PROCESSORS%)
else
  MKDIR := mkdir
	CP    := cp
	CPDIR := $(CP) -a
	NPROCS = $(shell grep -c 'processor' /proc/cpuinfo)
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
