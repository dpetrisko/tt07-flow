include Makefile.common

PATCH_ROOT     ?= $(TT_ROOT)/patches
OPENLANE_ROOT  ?= $(TT_ROOT)/openlane2
VERILATOR_ROOT ?= $(TT_ROOT)/verilator
IVERILOG_ROOT  ?= $(TT_ROOT)/iverilog
SYNLIG_ROOT    ?= $(TT_ROOT)/synlig
SV2V_ROOT      ?= $(TT_ROOT)/bsg_sv2v

tcl_tag       := $(TT_INSTALL_TOUCH_DIR)/tcl.any
tk_tag        := $(TT_INSTALL_TOUCH_DIR)/tk.any
openssl_tag   := $(TT_INSTALL_TOUCH_DIR)/openssl.any
python311_tag := $(TT_INSTALL_TOUCH_DIR)/python311.any
venv_tag      := $(TT_INSTALL_TOUCH_DIR)/venv.any
verilator_tag := $(TT_INSTALL_TOUCH_DIR)/verilator.any
iverilog_tag  := $(TT_INSTALL_TOUCH_DIR)/iverilog.any
synlig_tag    := $(TT_INSTALL_TOUCH_DIR)/synlig.any
sv2v_tag      := $(TT_INSTALL_TOUCH_DIR)/bsg_sv2v.any
pdk_tag       := $(TT_INSTALL_TOUCH_DIR)/pdk.$(PDK_VERSION)
ttsupport_tag := $(TT_INSTALL_TOUCH_DIR)/ttsupport.any
openlane_tag  := $(TT_INSTALL_TOUCH_DIR)/openlane.any

help:
	@echo "Targets:"
	@echo "    make venv"
	@echo "    make tools"

venv: | $(venv_tag)
tools:
	$(MAKE) $(iverilog_tag)
	$(MAKE) $(verilator_tag)
	$(MAKE) $(synlig_tag)
	$(MAKE) $(sv2v_tag)
	$(MAKE) $(pdk_tag)
	$(MAKE) $(openlane_tag)

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

$(openlane_tag): | $(venv_tag)
	$(MAKE) _check_venv
	cd $(OPENLANE_ROOT); $(PIP) install --force-reinstall .
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

