include Makefile.common

tcl_tag       := $(TT_INSTALL_TOUCH_DIR)/venv/tcl.any
tk_tag        := $(TT_INSTALL_TOUCH_DIR)/venv/tk.any
openssl_tag   := $(TT_INSTALL_TOUCH_DIR)/venv/openssl.any
python311_tag := $(TT_INSTALL_TOUCH_DIR)/venv/python311.any
ttsupport_tag := $(TT_INSTALL_TOUCH_DIR)/venv/ttsupport.any
venv_tag      := $(TT_INSTALL_TOUCH_DIR)/venv/venv.any

verilator_tag := $(TT_INSTALL_TOUCH_DIR)/tools/verilator.any
iverilog_tag  := $(TT_INSTALL_TOUCH_DIR)/tools/iverilog.any
synlig_tag    := $(TT_INSTALL_TOUCH_DIR)/tools/synlig.any
yosys_tag     := $(TT_INSTALL_TOUCH_DIR)/tools/yosys.any
slang_tag     := $(TT_INSTALL_TOUCH_DIR)/tools/slang.any
sv2v_tag      := $(TT_INSTALL_TOUCH_DIR)/tools/bsg_sv2v.any
pdk_tag       := $(TT_INSTALL_TOUCH_DIR)/tools/pdk.$(PDK_VERSION)
swig_tag      := $(TT_INSTALL_TOUCH_DIR)/tools/swig.any
spdlog_tag    := $(TT_INSTALL_TOUCH_DIR)/tools/spdlog.any
lemon_tag     := $(TT_INSTALL_TOUCH_DIR)/tools/lemon.any
re2_tag       := $(TT_INSTALL_TOUCH_DIR)/tools/re2.any
highs_tag     := $(TT_INSTALL_TOUCH_DIR)/tools/highs.any
ortools_tag   := $(TT_INSTALL_TOUCH_DIR)/tools/ortools.any
boost_tag     := $(TT_INSTALL_TOUCH_DIR)/tools/boost.any
abseil_tag    := $(TT_INSTALL_TOUCH_DIR)/tools/abseil.any
openlane_tag  := $(TT_INSTALL_TOUCH_DIR)/tools/openlane.any
openroad_tag  := $(TT_INSTALL_TOUCH_DIR)/tools/openroad.any
opensta_tag   := $(TT_INSTALL_TOUCH_DIR)/tools/opensta.any
openram_tag   := $(TT_INSTALL_TOUCH_DIR)/tools/openram.any

help:
	@echo "Targets:"
	@echo "    make venv"
	@echo "    make tools"

venv: | $(venv_tag)
tools:
	$(MAKE) $(iverilog_tag)
	$(MAKE) $(verilator_tag)
	$(MAKE) $(yosys_tag)
	#$(MAKE) $(synlig_tag)
	$(MAKE) $(sv2v_tag)
	$(MAKE) $(pdk_tag)
	$(MAKE) $(opensta_tag)
	$(MAKE) $(openroad_tag)
	$(MAKE) $(openram_tag)
	$(MAKE) $(openlane_tag)
	$(MAKE) $(slang_tag)

$(TT_INSTALL_WORK_DIR) $(TT_INSTALL_TOUCH_DIR):
	mkdir -p $@/venv
	mkdir -p $@/tools

_setup: $(TT_INSTALL_WORK_DIR) $(TT_INSTALL_TOUCH_DIR)
	git submodule update --init --recursive
	# Checkout cadenv if we can
	-git submodule update --init --checkout $(BSG_CADENV_DIR) || true

OPENSSL_VERSION := 1.1.1w
OPENSSL := openssl-$(OPENSSL_VERSION)
OPENSSL_URL := https://www.openssl.org/source/$(OPENSSL).tar.gz
OPENSSL_INSTALL := $(TT_INSTALL_DIR)/openssl
$(openssl_tag):
	$(MAKE) _setup
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(OPENSSL_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(OPENSSL); \
		CROSS_COMPILE="" ./config shared --prefix=$(OPENSSL_INSTALL) --openssldir=$(OPENSSL_INSTALL)
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(OPENSSL)
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(OPENSSL) install
	touch $@

TCL_VERSION := 8.6.14
TCL_SRC := tcl$(TCL_VERSION)
TCL_URL := http://prdownloads.sourceforge.net/tcl/$(TCL_SRC)-src.tar.gz
TCL_INSTALL := $(TT_INSTALL_DIR)/tcltk
$(tcl_tag): | $(openssl_tag)
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(TCL_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(TCL_SRC)/unix; \
		./configure --prefix=$(TCL_INSTALL) --enable-threads --enable-shared --enable-symbols; \
		$(MAKE) && $(MAKE) install
	touch $@

TK_VERSION := 8.6.14
TK_SRC := tk$(TK_VERSION)
TK_URL := http://prdownloads.sourceforge.net/tcl/$(TK_SRC)-src.tar.gz
TK_INSTALL := $(TT_INSTALL_DIR)/tcltk
$(tk_tag): | $(tcl_tag)
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(TK_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(TK_SRC)/unix; \
        ./configure --prefix=$(TCL_INSTALL) --with-tcl=$(TCL_INSTALL)/lib; \
        $(MAKE) && $(MAKE) install
	touch $@

PYTHON311_CFLAGS += -fprofile-arcs
PYTHON311_CFLAGS += -ftest-coverage
PYTHON311_LDFLAGS += -Wl,--rpath=$(OPENSSL_INSTALL)/lib
PYTHON311_LDFLAGS += -Wl,--rpath=$(TK_INSTALL)/lib
PYTHON311_LDFLAGS += -Wl,--rpath=$(TT_INSTALL_DIR)/lib
PYTHON311_LDFLAGS += -Wl,-lgcov
PYTHON311_LDFLAGS += --coverage
PYTHON311_VERSION := 3.11.4
PYTHON311 := Python-$(PYTHON311_VERSION)
PYTHON311_URL := https://www.python.org/ftp/python/$(PYTHON311_VERSION)/$(PYTHON311).tgz
$(python311_tag): | $(tk_tag)
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(PYTHON311_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(PYTHON311); \
		./configure \
			--enable-shared \
			--prefix="$(TT_INSTALL_DIR)" \
			--with-openssl="$(OPENSSL_INSTALL)" \
			--with-openssl-rpath="$(OPENSSL_INSTALL)/lib" \
			TCLTK_CFLAGS="-I$(TK_INSTALL)/include" \
			TCLTK_LIBS="-L$(TK_INSTALL)/lib -ltcl8.6 -ltk8.6" \
			CFLAGS="$(PYTHON311_CFLAGS)" \
			LDFLAGS="$(PYTHON311_LDFLAGS)"
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(PYTHON311) altinstall
	touch $@

$(ttsupport_tag): | $(python311_tag)
	cd $(TT_TOOL_ROOT); \
		git checkout tt07; git apply $(PATCH_ROOT)/tt-support-tools/*
	touch $@

$(venv_tag): | $(ttsupport_tag)
	$(TT_INSTALL_BIN_DIR)/python3.11 -m venv $(VENV_ROOT)
	$(VENV_ROOT)/bin/pip install --upgrade pip
	$(VENV_ROOT)/bin/pip install -r $(TT_ROOT)/requirements.txt
	$(VENV_ROOT)/bin/pip install -r $(TT_TOOL_ROOT)/requirements.txt
	$(VENV_ROOT)/bin/pip install -r $(PROJ_ROOT)/test/requirements.txt
	cp $(subst -I,,$(firstword $(shell python3-config --includes)))/pyconfig.h $(VENV_ROOT)/include
	touch $@

$(verilator_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(VERILATOR_DIR); \
		autoconf && ./configure --prefix=$(VENV_ROOT) && $(MAKE) && $(MAKE) install
	touch $@

$(iverilog_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(IVERILOG_ROOT); \
		autoconf && ./configure --prefix=$(VENV_ROOT) && $(MAKE) && $(MAKE) install
	touch $@

$(synlig_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(SYNLIG_ROOT); \
		$(MAKE) install
	touch $@

$(yosys_tag): | $(venv_tag)
	$(MAKE) _check_venv
	$(MAKE) -C $(YOSYS_ROOT) config-gcc
	$(MAKE) -C $(YOSYS_ROOT) PREFIX=$(VENV_ROOT)
	$(MAKE) -C $(YOSYS_ROOT) install PREFIX=$(VENV_ROOT)
	touch $@

SLANG_SOURCE_DIR ?= $(SLANG_ROOT)/third_party/slang
SLANG_BUILD_DIR ?= $(SLANG_SOURCE_DIR)/build
$(slang_tag): | $(yosys_tag)
	$(MAKE) _check_venv
	rm -rf $(SLANG_BUILD_DIR)
	rm -rf $(VENV_ROOT)/share/yosys/plugins
	$(CMAKE) -S $(SLANG_SOURCE_DIR) -B $(SLANG_BUILD_DIR) \
		-DCMAKE_INSTALL_PREFIX=$(VENV_ROOT) \
		-DCMAKE_BUILD_TYPE=Release \
		-DSLANG_USE_MIMALLOC=OFF \
		-DSLANG_INCLUDE_TESTS=OFF \
		-DSLANG_INCLUDE_TOOLS=OFF \
		-DBoost_NO_BOOST_CMAKE=ON \
		-DCMAKE_CXX_FLAGS="-fPIC"
	$(MAKE) -C $(SLANG_BUILD_DIR)
	$(MAKE) -C $(SLANG_BUILD_DIR) install
	mkdir -p $(VENV_ROOT)/share/yosys/plugins
	cd $(SLANG_ROOT); \
		$(VENV_ROOT)/bin/yosys-config --build $(VENV_ROOT)/share/yosys/plugins/slang.so \
			-std=c++20 -fPIC \
			-I$(VENV_ROOT)/share/yosys/include \
			-I$(VENV_ROOT)/include \
			-Wl,--whole-archive -L$(VENV_ROOT)/lib -lsvlang -lfmt -Wl,--no-whole-archive \
			slang_frontend.cc initial_eval.cc proc_usage.cc
	touch $@

$(pdk_tag): | $(venv_tag)
	$(MAKE) _check_venv
	volare enable --pdk-root=$(PDK_ROOT) --pdk=sky130 $(PDK_VERSION)
	cd $(PDK_ROOT); \
		git init; git add .; git commit -m "Initial commit"; cd -
	touch $@

$(sv2v_tag): | $(venv_tag)
	$(MAKE) _check_venv
	rm -rf $(TT_INSTALL_WORK_DIR)/Pyverilog
	git clone -b 1.1.3 https://github.com/PyHDI/Pyverilog.git $(TT_INSTALL_WORK_DIR)/Pyverilog
	cd $(TT_INSTALL_WORK_DIR)/Pyverilog; git apply $(SV2V_ROOT)/patches/pyverilog_*.patch
	cd $(TT_INSTALL_WORK_DIR)/Pyverilog;  $(PIP) install --force-reinstall .
	cd $(SV2V_ROOT); git apply $(PATCH_ROOT)/bsg_sv2v/*
	touch $@

SWIG_VERSION ?= 4.0.0
SWIG ?= swig-$(SWIG_VERSION)
SWIG_URL ?= https://sourceforge.net/projects/swig/files/swig/$(SWIG)/$(SWIG).tar.gz
SWIG_INSTALL ?= $(TT_INSTALL_DIR)/swig-install
$(swig_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(SWIG_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(SWIG); \
		./configure --prefix=$(SWIG_INSTALL); \
		$(MAKE) && $(MAKE) install
	touch $@

SPDLOG_INSTALL ?= $(TT_INSTALL_DIR)/spdlog-install
$(spdlog_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		$(GIT) clone https://github.com/gabime/spdlog.git; \
		cd spdlog && mkdir build && cd build; \
		$(CMAKE) -DCMAKE_INSTALL_PREFIX=$(SPDLOG_INSTALL) .. && $(MAKE) && $(MAKE) install
	touch $@

LEMON_VERSION ?= 1.3.1
LEMON ?= lemon-$(LEMON_VERSION)
LEMON_URL ?= http://lemon.cs.elte.hu/pub/sources/$(LEMON).tar.gz
LEMON_INSTALL ?= $(TT_INSTALL_DIR)/lemon-install
$(lemon_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(LEMON_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(LEMON); \
		mkdir build && cd build; \
		$(CMAKE) -DCMAKE_INSTALL_PREFIX=$(LEMON_INSTALL) .. && $(MAKE) && $(MAKE) install
	touch $@

ABSEIL_VERSION ?= master
ABSEIL ?= abseil-$(ABSEIL_VERSION)
ABSEIL_URL ?= https://github.com/abseil/abseil-cpp.git
ABSEIL_INSTALL ?= $(TT_INSTALL_DIR)/abseil-install
$(abseil_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		git clone -b $(ABSEIL_VERSION) $(ABSEIL_URL) $(ABSEIL)
	cd $(TT_INSTALL_WORK_DIR)/$(ABSEIL); \
		mkdir build && cd build; \
		$(CMAKE) -DCMAKE_INSTALL_PREFIX=$(ABSEIL_INSTALL) .. && $(MAKE) && $(MAKE) install
	touch $@

ORTOOLS_VERSION ?= _x86_64_CentOS-7.9.2009_cpp_v9.5.2237
ORTOOLS ?= or-tools$(ORTOOLS_VERSION)
ORTOOLS_URL ?= https://github.com/google/or-tools.git
ORTOOLS_INSTALL ?= $(TT_INSTALL_DIR)/or-tools-install
$(ortools_tag): | $(re2_tag) $(highs_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		git clone -b v9.5 $(ORTOOLS_URL) $(ORTOOLS)
	cd $(TT_INSTALL_WORK_DIR)/$(ORTOOLS); \
		mkdir build && cd build; \
		$(CMAKE) -DBUILD_DEPS=ON \
		-DUSE_SCIP=OFF \
		-DUSE_COINOR=OFF \
		-DUSE_SYSTEM_BOOST=ON \
		-DCMAKE_INSTALL_PREFIX=$(ORTOOLS_INSTALL) .. && $(MAKE) && $(MAKE) install
	touch $@

BOOST_VERSION := 1.82.0
BOOST := boost_$(subst .,_,$(BOOST_VERSION))
BOOST_URL := https://sourceforge.net/projects/boost/files/boost/$(BOOST_VERSION)/$(BOOST).tar.gz/download
$(boost_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(BOOST_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(BOOST); \
		./bootstrap.sh --prefix=$(VENV_ROOT) \
		--with-python=$(VENV_ROOT)/bin/python
	cd $(TT_INSTALL_WORK_DIR)/$(BOOST); \
		./b2 --prefix=$(VENV_ROOT) \
		--with-iostreams --with-test --with-serialization --with-system --with-thread \
		install
	touch $@

RE2_VERSION ?= main
RE2 ?= re2-$(RE2_VERSION)
RE2_URL ?= https://code.googlesource.com/re2
RE2_INSTALL ?= $(TT_INSTALL_DIR)/re2-install
$(re2_tag): | $(abseil_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		git clone -b $(RE2_VERSION) $(RE2_URL) $(RE2)
	cd $(TT_INSTALL_WORK_DIR)/$(RE2); \
		mkdir build && cd build; \
		absl_DIR=$(ABSEIL_INSTALL) \
		$(CMAKE)  -DCMAKE_INSTALL_PREFIX=$(RE2_INSTALL) .. && $(MAKE) && $(MAKE) install
		$(MAKE) && $(MAKE) install
	touch $@

HIGHS_VERSION ?= master
HIGHS ?= highs-$(HIGHS_VERSION)
HIGHS_URL ?= https://github.com/ERGO-Code/HiGHS.git
HIGHS_INSTALL ?= $(TT_INSTALL_DIR)/highs-install
$(highs_tag): | $(abseil_tag)
	$(MAKE) _check_venv
	cd $(TT_INSTALL_WORK_DIR); \
		git clone -b $(HIGHS_VERSION) $(HIGHS_URL) $(HIGHS)
	cd $(TT_INSTALL_WORK_DIR)/$(HIGHS); \
		mkdir build && cd build; \
		absl_DIR=$(ABSEIL_INSTALL) \
		$(CMAKE)  -DCMAKE_INSTALL_PREFIX=$(HIGHS_INSTALL) -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ .. && $(MAKE) && $(MAKE) install
		$(MAKE) && $(MAKE) install
	touch $@

$(opensta_tag): | $(swig_tag)
	$(MAKE) _check_venv
	mkdir -p $(TT_INSTALL_WORK_DIR)/opensta_build
	cd $(TT_INSTALL_WORK_DIR)/opensta_build; \
		PATH=$(SWIG_INSTALL)/bin:$(PATH) \
		SWIG_EXECUTABLE=$(SWIG_INSTALL)/bin \
		$(CMAKE) -DCMAKE_INSTALL_PREFIX=$(VENV_ROOT) -DBUILD_DEPS=ON $(OPENSTA_ROOT)
	cd $(TT_INSTALL_WORK_DIR)/opensta_build; \
		$(MAKE) && $(MAKE) install
	touch $@

$(openram_tag):
	$(MAKE) _check_venv
	cd $(OPENRAM_ROOT); \
		$(MAKE) -j1 sky130-pdk sky130-install
	cd $(OPENRAM_ROOT); \
		$(MAKE) library
	touch $@

$(openroad_tag): | $(swig_tag) $(spdlog_tag) $(lemon_tag) $(abseil_tag) $(ortools_tag) $(boost_tag)
	$(MAKE) _check_venv
	mkdir -p $(TT_INSTALL_WORK_DIR)/openroad_build
	cd $(TT_INSTALL_WORK_DIR)/openroad_build; \
		PATH=$(SWIG_INSTALL)/bin:$(PATH) \
		SWIG_EXECUTABLE=$(SWIG_INSTALL)/bin \
		absl_DIR=$(ABSEIL_INSTALL) \
		lemon_DIR=$(LEMON_INSTALL) \
		ortools_DIR=$(ORTOOLS_INSTALL) \
		Protobuf_DIR=$(ORTOOLS_INSTALL) \
		Cdl_DIR=$(ORTOOLS_INSTALL) \
		spdlog_DIR=$(SPDLOG_INSTALL) \
		$(CMAKE) -DCMAKE_INSTALL_PREFIX=$(VENV_ROOT) -DBUILD_DEPS=ON $(OPENROAD_ROOT)
	touch $@

$(openlane_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(OPENLANE_ROOT); git apply $(PATCH_ROOT)/openlane2/*patch
	cd $(OPENLANE_ROOT); \
		$(PIP) install --force-reinstall .
	touch $@

clean:
	rm -rf $(TT_INSTALL_TOUCH_DIR)/
	rm -rf $(TT_INSTALL_WORK_DIR)/

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all: clean
	cd $(TOP); git clean -fdx; git submodule deinit -f .

_check_venv:
	python -c "import os; os.environ['VIRTUAL_ENV']" || (echo "venv not detected" && false)
	echo "venv detected!"

