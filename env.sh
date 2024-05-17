export PDK_ROOT=${HOME}/.volare
export PDK=sky130A
export PDK_TYPE=sky130_fd_sc_hd
export TT_ROOT=${HOME}/scratch/tt
export PROJ_ROOT=${TT_ROOT}/tt07-dll
export PATH=${TT_ROOT}/synlig/out/current/bin:${PATH}
export BASEJUMP_STL_DIR=${PROJ_ROOT}/src/basejump_stl
export OPENLANE_ROOT=${TT_ROOT}/OpenLane
export OPENLANE_TAG=2024.05.14
export OPENLANE_IMAGE_NAME=efabless/openlane:${OPENLANE_TAG}
export VENV_ROOT=${TT_ROOT}/.venv
export TT_TOOL_ROOT=${TT_ROOT}/tt-support-tools

if [ ! -d ${VENV_ROOT} ]; then
	python3 -m venv ${VENV_ROOT}
	cd ${TT_TOOL_ROOT}/ && git apply ../patches/tt-support-tools/*
	cd -
	pip -r install ${TT_TOOL_ROOT}/requirements.txt
	pip -r install ${PROJ_ROOT}/test/requirements.txt
fi

source ${VENV_ROOT}/bin/activate

