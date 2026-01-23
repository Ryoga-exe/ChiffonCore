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
