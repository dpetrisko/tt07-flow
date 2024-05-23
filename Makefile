include Makefile.common

PATCH_ROOT     ?= $(TT_ROOT)/patches
TT_TOOL_ROOT   ?= $(TT_ROOT)/tt-support-tools
OPENLANE_ROOT  ?= $(TT_ROOT)/openlane2
VERILATOR_ROOT ?= $(TT_ROOT)/verilator
IVERILOG_ROOT  ?= $(TT_ROOT)/iverilog
SYNLIG_ROOT    ?= $(TT_ROOT)/synlig
SV2V_ROOT      ?= $(TT_ROOT)/bsg_sv2v

openssl_tag   := $(TT_INSTALL_TOUCH_DIR)/openssl.any
python311_tag := $(TT_INSTALL_TOUCH_DIR)/python311.any
venv_tag      := $(TT_INSTALL_TOUCH_DIR)/venv.any
verilator_tag := $(TT_INSTALL_TOUCH_DIR)/verilator.any
iverilog_tag  := $(TT_INSTALL_TOUCH_DIR)/iverilog.any
synlig_tag    := $(TT_INSTALL_TOUCH_DIR)/synlig.any
sv2v_tag      := $(TT_INSTALL_TOUCH_DIR)/bsg_sv2v.any
pdk_tag       := $(TT_INSTALL_TOUCH_DIR)/pdk.$(PDK_VERSION)
tttool_tag    := $(TT_INSTALL_TOUCH_DIR)/tttool.any

help:
	@echo "Targets:"
	@echo "    make venv"
	@echo "    make tools"

_check_venv:
	python -c "import os; os.environ['VIRTUAL_ENV']" || (echo "venv not detected" && false)
	echo "venv detected!"

venv: | $(venv_tag)
tools: $(verilator_tag) $(iverilog_tag) $(synlig_tag) $(pdk_tag) $(sv2v_tag) $(openlane_tag)

$(TT_INSTALL_WORK_DIR) $(TT_INSTALL_TOUCH_DIR):
	mkdir -p $@

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

PYTHON311_VERSION := 3.11.4
PYTHON311 := Python-$(PYTHON311_VERSION)
PYTHON311_URL := https://www.python.org/ftp/python/$(PYTHON311_VERSION)/$(PYTHON311).tgz
$(python311_tag): | $(openssl_tag)
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(PYTHON311_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(PYTHON311); \
		./configure \
			--enable-shared \
			--enable-optimizations \
			--prefix=$(TT_INSTALL_DIR) \
			--with-openssl=$(OPENSSL_INSTALL) \
			--with-openssl-rpath=auto \
			TCLTK_LIBS="-ltk8.5 -ltcl8.5" \
			LDFLAGS="-Wl,--rpath=$(OPENSSL_INSTALL)/lib -Wl,--rpath=$(TT_INSTALL_DIR)/lib"
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(PYTHON311) altinstall
	touch $@

$(tttool_tag): | $(python311_tag)
	-cd $(TT_TOOL_ROOT); \
		git checkout tt07; git apply $(PATCH_ROOT)/tt-support-tools/*
	touch $@

$(venv_tag): | $(tttool_tag)
	$(TT_INSTALL_BIN_DIR)/python3.11 -m venv $(VENV_ROOT)
	$(VENV_ROOT)/bin/pip install --upgrade pip
	$(VENV_ROOT)/bin/pip install -r $(TT_ROOT)/requirements.txt
	$(VENV_ROOT)/bin/pip install -r $(TT_TOOL_ROOT)/requirements.txt
	$(VENV_ROOT)/bin/pip install -r $(PROJ_ROOT)/test/requirements.txt
	touch $@

$(verilator_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(VERILATOR_ROOT); \
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
	cp -r $(SYNLIG_ROOT)/out/release/bin/* $(VENV_ROOT)/bin
	cp -r $(SYNLIG_ROOT)/out/release/bin/* $(VENV_ROOT)/lib
	cp -r $(SYNLIG_ROOT)/out/release/bin/* $(VENV_ROOT)/share
	touch $@

$(pdk_tag): | $(venv_tag)
	$(MAKE) _check_venv
	volare enable --pdk-root=$(PDK_ROOT) --pdk=sky130 $(PDK_VERSION)
	cd $(PDK_ROOT); \
		git init; git commit -am "Initial commit"; cd -
	touch $@

$(sv2v_tag): | $(venv_tag)
	$(MAKE) _check_venv
	rm -rf $(TT_INSTALL_WORK_DIR)/Pyverilog
	git clone -b 1.1.3 https://github.com/PyHDI/Pyverilog.git $(TT_INSTALL_WORK_DIR)/Pyverilog
	cd $(TT_INSTALL_WORK_DIR)/Pyverilog; git apply $(SV2V_ROOT)/patches/pyverilog_*.patch
	cd $(TT_INSTALL_WORK_DIR)/Pyverilog;  $(PIP) install --force-reinstall .
	cd $(SV2V_ROOT); git apply $(PATCH_ROOT)/bsg_sv2v/*
	touch $@

$(openlane2_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(OPENLANE_ROOT); $(PIP) install --force-reinstall .
	touch $@

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	rm -rf $(TT_INSTALL_DIR)/
	cd $(TOP); git clean -fdx; git submodule deinit -f .

