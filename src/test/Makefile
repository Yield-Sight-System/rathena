# Makefile for rAthena threading runtime tests

CXX = g++
LIBCONFIG_INCLUDE = -I../../3rdparty/libconfig
CXXFLAGS = -std=c++17 -pthread -Wall -Wextra -g -O0 -I.. $(LIBCONFIG_INCLUDE)
LDFLAGS = -pthread

# Common object files needed
COMMON_DIR = ../common
COMMON_OBJ = $(COMMON_DIR)/obj/threading.o \
             $(COMMON_DIR)/obj/showmsg.o \
             $(COMMON_DIR)/obj/strlib.o \
             $(COMMON_DIR)/obj/malloc.o

# Test executables
TESTS = test_threading_runtime

.PHONY: all clean test

all: $(TESTS)

test_threading_runtime: test_threading_runtime.cpp $(COMMON_OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $< $(COMMON_OBJ) $(LDFLAGS)
	@echo "✅ Built: test_threading_runtime"

test: $(TESTS)
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║         Running Threading Runtime Tests                ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@./test_threading_runtime

clean:
	rm -f $(TESTS)
	@echo "✅ Cleaned test executables"

help:
	@echo "rAthena Threading Test Suite"
	@echo ""
	@echo "Targets:"
	@echo "  all                  - Build all tests (default)"
	@echo "  test_threading_runtime - Build threading runtime test"
	@echo "  test                 - Build and run all tests"
	@echo "  clean                - Remove test executables"
	@echo "  help                 - Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  make                 # Build tests"
	@echo "  make test            # Build and run tests"
	@echo "  make clean           # Clean up"
