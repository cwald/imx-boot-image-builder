#!/bin/bash

# imx-bib.sh : i.MX Boot Image Builder
# 05/03/2022 - Curtis Wald curtis.wald@nxp.com
#              concept from Robert Mcewan

# Description: Build boot image
# i.MX application processors supported: 8mq 8mm, 8mn, 8mp, 8ulp
# Usage example: ./imx-bib.sh -p 8ulp

# Operation:

# All required repositories and binary files are downloaded. If this
# operation has already been performed then subsequent script runs
# will skip downloading again. Run the script with the -r to delete all
# if needing to start from scratch.

# Once downloaded files are available, there are three build functions
# called: build_uboot, build_atf, and build_image. When build_image
# completes the flash.bin file is found at the same dir level as the
# script. For example if 8ulp was the build, then 8ulp_evk_flash.bin
# is created.


# For each different i.MX chip, u-boot must be re-built. Provide the
# -c script argument to clean and then build if the downloads have
# completed.  Example: imx-bib.sh -p 8mp -c

# exit script on any error
#set -e
# keep track of the last executed command
#trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
#trap 'echo "\"${last_command}\" command failed with exit code $?."' EXIT


#Script version
SCR_VER="3.0"

# Define script colors
bold=`tput bold`
clr=`tput sgr0` # turn off attributes
black=`tput setaf 0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
cyan=`tput setaf 6`
white=`tput setaf 7`

# meta-imx repo
REPO_METAIMX="https://github.com/nxp-imx/meta-imx"

# Base name location for content download
REPO_GIT="https://github.com/nxp-imx"
NXP_FILES="https://www.nxp.com/lgfiles/NMG/MAD/YOCTO"
IMX_SW="https://www.nxp.com/imxlinux"

# Make command option to build silent. Providing -d to script disables
MFLAG=-s

BDIR=`pwd`

VERULP=""
VERULPtmp=""

# Description: print help message and usage 
function usage {
	echo "Usage: $(basename $0) [-h] -p <soc> [-b] [-w <A0|A1>] [-c]" 2>&1
	echo 'Create bootimage. Version ' ${SCR_VER}
	echo '   -p soc       mandatory: options: 8ulp 8mm 8mn 8mp 8mq 93' 
	echo '   -b           optional: latest if not specified
                      BSP Release in the form yocto_release-nxp_version
		      example: -b hardknott-5.10.72-2.2.0'
	echo '   -w A0|A1|A2  which 8ULP version, default A1. Note: A2 uses A1.bin'
	echo '   -m           EVK with ddr4 memory. Supported: 8mn, 8mm, 8mp. If no -m, EVK with LPDDR4'
	echo '   -c           make clean then make'
	echo '   -r           remove all'
	echo '   -d           enable script debug '
	echo '   -h           Help message'
	echo ''
	echo "${bold} Example 8ulp A1:    ./$(basename $0) -p 8ulp ${clr}"
	echo "${bold} Example 8mn LPDDR4: ./$(basename $0) -p 8mn ${clr}"
	echo "${bold} Example 8mn DDR4:   ./$(basename $0) -p 8mn -m ${clr}"
        exit 1
}

# Description: remove all downloads and generated images
function remove_all {
    echo "Removing all images and downloads"
    rm -fr fw-imx
    rm -fr imx-atf
    rm -fr imx-mkimage
    rm -fr m33_demo
    rm -fr meta-imx
    rm -fr sentinel ele
    rm -fr uboot-imx
    rm -fr upower
    rm -fr *.bin
}

# if no input argument found, exit the script with usage
if [[ ${#} -eq 0 ]]; then
   usage
fi

# Define list of arguments expected in the input
optstring=":mhrcdp:b:w:"

while getopts ${optstring} arg; do
    case ${arg} in
	w)
	    VERULPtmp="${OPTARG}"
	    VERULP=$(echo ${VERULPtmp}|tr "[:lower:]" "[:upper:]");
	    echo "VERULP = " $VERULP
	    SOC_FLASH_NAME=$SOC"_"$VERULP"_evk_flash.bin"
	    ;;
	p)
	    SOC="${OPTARG}"
	    SOCU=$(echo ${SOC}|tr "[:lower:]" "[:upper:]");
	    echo "SOC  = " $SOC
	    if [[ $SOC == "8ulp" ]]; then
		MKIMG_DIR=iMX8ULP
		FLASH_IMG=flash_singleboot_m33
		VERULP="A2"
		UBOOT_DEFCONFIG="imx8ulp_evk_defconfig"
		SOC_FLASH_NAME=$SOC"_"$VERULP"_evk_flash.bin"
	    elif [[ $SOC == "93" ]]; then
		MKIMG_DIR=iMX9
		FLASH_IMG=flash_singleboot
		UBOOT_DEFCONFIG="imx93_11x11_evk_defconfig"
		SOC_FLASH_NAME="imx"$SOC"_11x11""_evk_flash.bin"
	    else
		MKIMG_DIR=iMX8M
		FLASH_IMG=flash_evk
		UBOOT_DEFCONFIG="imx"$SOC"_evk_defconfig"
		SOC_FLASH_NAME=$SOC"_evk_flash.bin"
	    fi
	    ;;
	b)
		RELEASE="${OPTARG}"
		;;
	m)
	    if [[ $SOC == "8mm" || $SOC == "8mp" || $SOC == "8mn" ]]; then
		FLASH_IMG=flash_ddr4_evk
		UBOOT_DEFCONFIG="imx"$SOC"_ddr4_evk_defconfig"
		SOC_FLASH_NAME=$SOC"_ddr4_evk_flash.bin"
	    else
		echo $SOC " EVK does not support ddr4"
		exit 1
	    fi
	    ;;
	c)
	    CLEAN=y
	    ;;
	d)
	    V=1
	    unset MFLAG
	    ;;
	r)
	    remove_all; exit;;
        h)
	    usage;;
	?)
	echo "Invalid option: -${OPTARG}."
	echo
	usage
	;;
    esac
done




# Description: Install host packages if missing
function hostPkg {
    [ ! -f /usr/bin/aarch64-linux-gnu-gcc ] && \
	sudo apt install -y crossbuild-essential-arm64 gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

    [ ! -f /usr/bin/curl ] && \
	sudo apt install -y curl

    [ ! -f /usr/bin/bison ] && \
	sudo apt install -y bison

    [ ! -f /usr/bin/flex ] && \
	sudo apt install -y flex

    [ ! -d /usr/include/openssl ] && \
	sudo apt install -y libssl-dev

    [ ! -d /usr/include/gnutls ] && \
        sudo apt install -y libgnutls28-dev

    [ ! -f /usr/bin/dtc ] && \
	sudo apt install -y device-tree-compiler

    [ ! -f /usr/include/uuid/uuid.h ] && \
    sudo apt install -y uuid-dev 
}


# Description: clone meta-imx
function repo_get_metaimx {

	if [ -z "$RELEASE" ]; then
        README=$(wget -qO- $IMX_SW | grep README | head -1 | cut -d '"' -f6 | sed 's/blob/raw/g')
        echo "README " $README
	    BRANCH=$(wget -qO- $README |  awk '/\$: repo init/ && count++==1 {print $7}'|head -1|sed 's/\"<>pre//')
        echo "BRANCH " $BRANCH
	    MANIFEST=$(wget -qO- $README |  awk '/\$: repo init/ && count++==1 {print $9}'|head -1)
	    RELNAME=$(echo $BRANCH | cut -d '-' -f3)
        echo "RELNAME " $RELNAME
	    RELVER=$(basename $MANIFEST .xml | cut -b 5-|sed 's/\.xml\"><pre//')
        echo "RELVER " $RELVER
		RELEASE=$RELNAME-$RELVER
        echo "RELEASE " $RELEASE
	fi
    #exit
    echo "git clone $REPO_GIT/meta-imx -b $RELEASE "
    git clone $REPO_GIT/meta-imx -b $RELEASE

}


# Description: git clone github repositories
function repo_get {
    [ -n "$V" ] && set -x
    git clone $REPO_GIT/$1 -b $TAG --depth=1
    [ -n "$V" ] && set +x
}


# Global Variables
SCR=""
FN_FW_POWER="firmware-upower"
FN_FW_SENTINEL="firmware-sentinel"
FN_FW_ELE="firmware-ele-imx"
FN_M33DEMO="imx8ulp-m33-demo"
FN_FW_IMX="firmware-imx"
FW_IMX=""

LINUX_KER=""
LINUX_REL=""
FWPOW=""
FWSENT=""
FWELE=""
FWM33DEMO=""
TAG=""

ismx93()
{
    if [ $SOC == "93" ]; then
        true; return
    else
        false; return
    fi;
}

ismx8ulp()
{
    if [ $SOC == "8ulp" ]; then
        true; return
    else
        false; return
    fi;
}

# i.MX devices that have security firmware, package name changed
# firmware-sentinel to firmware-ele in 6.1.55-2.2.0.  
isELE()
{
    if [ "$LINUX_KER" \< "6.1.55" ]; then
        false; return
    else
        true; return
    fi
}

# Description: set version variables from the SCR
# NOTE: meta-imx must be available before calling
function setupVar {
    cd meta-imx
    SCR=`ls SCR-*`
    REV=$(egrep "^Release - Linux" $SCR)
    LINUX_KER=$(echo $REV | cut -d ' ' -f4 | cut -d '-' -f1 )
    LINUX_REL=$(echo $REV | cut -d ' ' -f4 | cut -d '-' -f2)
    TAG="lf-$LINUX_KER-$LINUX_REL"

# i.MX 93 A0 : 6.1.22-2.0.0 - last release supporting A0 
# i.mx 93 A1 : 6.1.36-2.1.0 - first release supporting A1, future releases only A1
    if [ "$LINUX_KER" \< 6.1.36 ]; then
	    AHAB93="A0"
    else
	    AHAB93="A1"
    fi

    echo "LINUX_KER= " $LINUX_KER
    echo "LINUX_REL= " $LINUX_REL
    echo "TAG =      " $TAG
    ismx93 &&  echo "AHA93=     " $AHAB93 

    FW_IMX_SCR=$(grep $FN_FW_IMX $SCR)
    FW_IMX=$(echo $FW_IMX_SCR | cut -d ' ' -f2)
    echo "FW_IMX =   " $FW_IMX

    if [[ $SOC == "8ulp"  ||  $SOC == "93" ]]; then
	ismx8ulp && FW_UPOW=$(grep $FN_FW_POWER $SCR); \
	FWPOW=$(echo $FW_UPOW | cut -d ' ' -f2) 

    if  isELE; then
	    FW_ELE=$(grep $FN_FW_ELE $SCR); \
	    FWELE=$(echo $FW_ELE | cut -d ' ' -f2); \
       echo "FWELE  =   " $FWELE
    else
        FW_SENT=$(grep $FN_FW_SENTINEL $SCR); \
	    FWSENT=$(echo $FW_SENT | cut -d ' ' -f2); \
        echo "FWSENT =   " $FWSENT    
    fi

	FW_M33=$(grep $FN_M33DEMO $SCR)
	FWM33DEMO=$(echo $FW_M33 | cut -d ' ' -f2)

	ismx8ulp && echo "FWPOW =    " $FWPOW
	echo "FWM33DEMO= " $FWM33DEMO
    
    fi

    echo "FLASH_IMG= " $FLASH_IMG
    echo "UBOOT_DEFCONFIG= " $UBOOT_DEFCONFIG
    cd ..
}

# Description: check for bin files and install if needed
function fw_install {
    cd $BDIR	# start at top level dir

    # check uboot-imx - install ddr files if missing
    if [[ ! -f uboot-imx/lpddr4_pmu_train_1d_dmem.bin ]]; then
	echo "Installing ddr files in u-boot"
	cp fw-imx/firmware-imx*/firmware/ddr/synopsys/*.bin $BDIR/uboot-imx
    fi

    # check imx-mkimage - install lpddr4 if missing
    if [[ ! -f imx-mkimage/$MKIMG_DIR/lpddr4_pmu_train_1d_dmem.bin ]]; then
	echo "Installing ddr files in imx-mkimage/$MKIMG_DIR"
	cp fw-imx/firmware-imx*/firmware/ddr/synopsys/*.bin imx-mkimage/$MKIMG_DIR
	[ $SOC != "8ulp" ] && cp fw-imx/firmware-imx*/firmware/hdmi/cadence/signed_hdmi_imx8m.bin imx-mkimage/$MKIMG_DIR

    fi
}

# Description: Download firmware-imx which provides ddr and hdmi bin
# files. 
function fw_fetch {
    mkdir -p fw-imx
    cd fw-imx
    [ -n "$V" ] && set -x
    curl -R -k -f $NXP_FILES/$FW_IMX -o ./fw-imx.bin
    chmod a+x ./fw-imx.bin
    ./fw-imx.bin --auto-accept

    fw_install
    [ -n "$V" ] && set +x
}

# Description: 8ulp Sentinel firmware
function sentinel_fetch {
    echo "Creating Sentinel directory"
    mkdir -p sentinel
    cd sentinel
    curl -R -k -f $NXP_FILES/$FWSENT -o ./sent.bin
    chmod a+x ./sent.bin
    ./sent.bin --auto-accept
    cd firmware-sentinel-*
    cp mx8ulpa?-ahab-container.img ../../imx-mkimage/iMX8ULP
    cp mx93*.img ../../imx-mkimage/iMX9
    cd ../..
}
# Description: 8ulp EdgeLockEnclave (ELE) firmware
function ele_fetch {
    echo "Creating ELE directory"
    mkdir -p ele
    cd ele
    curl -R -k -f $NXP_FILES/$FWELE -o ./ele.bin
    chmod a+x ./ele.bin
    ./ele.bin --auto-accept
    cd firmware-*
    cp mx8ulpa?-ahab-container.img ../../imx-mkimage/iMX8ULP
    cp mx93*.img ../../imx-mkimage/iMX9
    cd ../..
}


# Description: 8ulp uPower firmware
function upwr_fetch {
    mkdir upower
    cd  upower
    curl -R -k -f $NXP_FILES/$FWPOW -o ./pwr.bin
    chmod a+x ./pwr.bin
    ./pwr.bin --auto-accept
    cd firmware-upower-*
    cp upower_a?.bin ../../imx-mkimage/iMX8ULP
    
    if [[ $VERULP == A[12] ]]; then
	ln -fs ../../imx-mkimage/iMX8ULP/upower_a1.bin ../../imx-mkimage/iMX8ULP/upower.bin;
    else
	echo "Trying to use upower_a0"
	ln -fs ../../imx-mkimage/iMX8ULP/upower_a0.bin ../../imx-mkimage/iMX8ULP/upower.bin;
    fi
    
    cd ../..
}

# Description: 8ulp M33 Demo
function m33demo_fetch {
    
    mkdir m33_demo
    cd m33_demo
    curl -R -k -f $NXP_FILES/$FWM33DEMO -o demo.bin
    chmod a+x ./demo.bin
    ./demo.bin --auto-accept
    cd imx8ulp-m33-demo-*
    cp imx8ulp_m33_TCM_rpmsg_lite_str_echo_rtos.bin ../../imx-mkimage/iMX8ULP/m33_image.bin
    cd ../..
}

# Description: Download git repos and NXP binary files if dir for each
# not found. 
function download {
    [ ! -d uboot-imx ] && repo_get uboot-imx
    [ ! -d imx-atf ] && repo_get imx-atf
    [ ! -d imx-mkimage ] && repo_get imx-mkimage
    [ ! -d fw-imx ] && fw_fetch

    if ismx8ulp; then
        if [ ! -d upower ]; then
            upwr_fetch
        fi
    fi

    if [[ $SOC == '8ulp'  ||  $SOC == '93' ]]; then
	    [ ! -d m33_demo ] && m33demo_fetch
        if isELE; then
	        [ ! -d ele ] && ele_fetch
        else
            [ ! -d sentinel ] && sentinel_fetch
	    fi
    fi
}

#----- Build functions -----

# Description: Build u-boot, if -c script option, clean target first
function build_uboot {
    echo ${cyan}"Building u-boot"${clr}

    [ -n "$V" ] && set -x

    cd uboot-imx
    [ -n "$CLEAN" ] && make ${MFLAG} distclean
    [ ! -f .config ] && make ${MFLAG} $UBOOT_DEFCONFIG
    make ${MFLAG} -j `nproc`
    
    cp ./tools/mkimage ../imx-mkimage/$MKIMG_DIR/mkimage_uboot
    cp ./u-boot-nodtb.bin ../imx-mkimage/$MKIMG_DIR/
    cp ./u-boot.bin ../imx-mkimage/$MKIMG_DIR/
    cp ./spl/u-boot-spl.bin ../imx-mkimage/$MKIMG_DIR/
    cp ./arch/arm/dts/imx$SOC*-evk.dtb ../imx-mkimage/$MKIMG_DIR/

    cd ..
    [ -n "$V" ] && set +x

    echo ${green}U-boot build complete${clr}
}


# Description: build imx-atf (Arm Trusted Firmware)
function build_atf {
    echo ${cyan}Building ATF Image${clr}
    cd imx-atf/
    [ -n "$CLEAN" ] && make clean PLAT=imx$SOC
    [ -n "$V" ] && set -x
    make ${MFLAG} PLAT=imx$SOC bl31
    [ -n "$V" ] && set +x
    cp ./build/imx$SOC/release/bl31.bin ../imx-mkimage/$MKIMG_DIR
    cd ..
    echo ${green}ATF build complete${clr}
}


# Description: All dependencies completed, build flash.bin
build_image() {
    # Build the boot image
    echo ${cyan}Building Boot Image${clr}
    [ -n "$V" ] && set -x

    # set uPower FW version if 8ULP
    if [[ $SOC == "8ulp" ]]; then

	pushd imx-mkimage/iMX8ULP
	
	if [[ $VERULP == A[12] ]]; then
	    ln -fs upower_a1.bin upower.bin;
	else
	ln -fs upower_a0.bin upower.bin;
	fi

	popd
    fi
    
    cd imx-mkimage/
    pwd
    [ -n "$CLEAN" ] && make SOC=iMX$SOCU clean 
    if [[ $SOC == "8ulp" ]]; then
	make SOC=iMX$SOCU REV=$VERULP $FLASH_IMG
        cp ./$MKIMG_DIR/flash.bin ../${SOC_FLASH_NAME}
    elif [[ $SOC == "93" ]]; then
	make SOC=iMX9 REV=$AHAB93 $FLASH_IMG
	cp ./$MKIMG_DIR/flash.bin ../${SOC_FLASH_NAME}
    else
	make SOC=iMX$SOCU $FLASH_IMG
        cp ./$MKIMG_DIR/flash.bin ../${SOC_FLASH_NAME}
    fi
    cd ..    
    [ -n "$V" ] && set +x
#    echo ${green}Boot Image success!${clr}
}
#------------------------------
# 
# hostPkg   install host packages if missing 
hostPkg

# setup environment to cross-compile
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# First get meta-imx repo which has SCR for package versions
[ ! -d meta-imx ] && repo_get_metaimx

# setup variables for this release using meta-imx/SCR-### versions
setupVar

# Download i.mx software
download

# Based on i.MX chip, setup firmware files
fw_install

# Call functions to build
build_uboot
build_atf
build_image
echo "${yellow}Done ${SOC_FLASH_NAME} ${clr}"
exit 0
