include Makefile.common

python311_tag := $(TT_INSTALL_TOUCH_DIR)/python311.any
openssl_tag   := $(TT_INSTALL_TOUCH_DIR)/openssl.any
venv_tag      := $(TT_INSTALL_TOUCH_DIR)/venv.any
verilator_tag := $(TT_INSTALL_TOUCH_DIR)/verilator.any
iverilog_tag := $(TT_INSTALL_TOUCH_DIR)/iverilog.any
synlig_tag := $(TT_INSTALL_TOUCH_DIR)/synlig.any

all:
	@echo "Targets:"
	@echo "\tmake venv"
	@echo "\tmake tools"

check_venv:
	python -c "import os; os.environ['VIRTUAL_ENV']" || echo ".venv not activated"

venv: | $(venv_tag)
tools: | $(verilator_tag) $(iverilog_tag) $(synlig_tag)

$(TT_INSTALL_WORK_DIR) $(TT_INSTALL_TOUCH_DIR):
	mkdir -p $@

OPENSSL_VERSION := 1.1.1w
OPENSSL := openssl-$(OPENSSL_VERSION)
OPENSSL_URL := https://www.openssl.org/source/$(OPENSSL).tar.gz
OPENSSL_INSTALL := $(TT_INSTALL_DIR)/openssl
$(openssl_tag): $(TT_INSTALL_WORK_DIR) $(TT_INSTALL_TOUCH_DIR)
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(OPENSSL_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(OPENSSL); \
		CROSS_COMPILE="" ./config shared --prefix=$(OPENSSL_INSTALL) --openssldir=$(OPENSSL_INSTALL)
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(OPENSSL)
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(OPENSSL) install
	$(TOUCH) $@

PYTHON311_VERSION := 3.11.4
PYTHON311 := Python-$(PYTHON311_VERSION)
PYTHON311_URL := https://www.python.org/ftp/python/$(PYTHON311_VERSION)/$(PYTHON311).tgz
$(python311_tag): $(openssl_tag)
	cd $(TT_INSTALL_WORK_DIR); \
		$(WGET) -qO- $(PYTHON311_URL) | $(TAR) xzv
	cd $(TT_INSTALL_WORK_DIR)/$(PYTHON311); \
		./configure \
			LDFLAGS="-L$(OPENSSL_INSTALL)/lib" \
			--with-openssl=$(OPENSSL_INSTALL) \
			--with-openssl-rpath=auto \
			--prefix=$(TT_INSTALL_DIR)
	$(MAKE) -C $(TT_INSTALL_WORK_DIR)/$(PYTHON311) altinstall
	$(TOUCH) $@

$(venv_tag): | $(openssl_tag) $(python311_tag)
	$(TT_INSTALL_BIN_DIR)/python3.11 -m venv $(VENV_ROOT)
	cd $(TT_TOOL_ROOT) && git apply $(PATCH_ROOT)/tt-support-tools/* || git apply --reverse --check $(PATCH_ROOT)/tt-support-tools/*
	$(VENV_ROOT)/bin/pip install --upgrade pip
	$(VENV_ROOT)/bin/pip install -r $(TT_ROOT)/requirements.txt
	$(VENV_ROOT)/bin/pip install -r $(TT_TOOL_ROOT)/requirements.txt
	$(VENV_ROOT)/bin/pip install -r $(PROJ_ROOT)/test/requirements.txt
	$(TOUCH) $@

$(verilator_tag): check_venv
	cd $(VERILATOR_ROOT); \
		autoconf && ./configure --prefix=$(VENV_ROOT) && $(MAKE) && $(MAKE) install
	touch $@

$(iverilog_tag): check_venv
	cd $(IVERILOG_ROOT); \
		autoconf && ./configure --prefix=$(VENV_ROOT) && $(MAKE) && $(MAKE) install
	touch $@

$(synlig_tag): check_venv
	cd $(SYNLIG_ROOT); \
		$(MAKE) install
	cp -r $(SYNLIG_ROOT)/out/release/bin/* $(VENV_ROOT)/bin
	cp -r $(SYNLIG_ROOT)/out/release/bin/* $(VENV_ROOT)/lib
	cp -r $(SYNLIG_ROOT)/out/release/bin/* $(VENV_ROOT)/share
	touch $@

