#!/bin/bash

###########################################################################################
# Lg G3 Build Script Kraken (C) 2016   UpDated: 08/17/2016  
# Original By RenderBroken
# Modified By Eliminater74 
# Modified for Kraken by bthorne79  #                                    # Used and modified with permisson by Eliminater74
#                                                                                         #
# Build Script W/AnyKernel V2 Support Plus        07/22/2015                              #
#                                                                                         #
# Added: YYYYMMDD_HHMMSS Added to end of Zip Package                                      #
# Added: SignApk to sign all zips     <--- removed for now                                #
# Added: Build.log Error Only or Full Log                                                 #
# Added: Automatic change anykernel.sh device settings                                    #
# Added: Dialog Menu system for nice clean easy GUI environment                           #
# Added: Fail Safe method for When Builds End                                             #
# Added: batch Build                                                                      #
# Added: External Configure File For easy editing                                         #
# Added: Bump Version on all Defconfigs, ZipNames and anykernel.sh                        #
# Added: Tweaks On/Off                                                                    
#                                                     #
#                                                                                         #
#                                                                                         #
###########################################################################################

### DO NOT EDIT ANYTHING BELOW THIS LINE ###
### EDIT ONLY AnyKernel.cfg File Only ###

###########################################################################################

# Store menu options selected by the user
INPUT=/tmp/menu.sh.$$
 
# Storage file for displaying cal and date command output
OUTPUT=/tmp/output.sh.$$

# trap and delete temp files
trap "rm $OUTPUT; rm $INPUT; exit" SIGHUP SIGINT SIGTERM

# Bash Color
green='\033[01;32m'
red='\033[01;31m'
blink_red='\033[05;31m'
restore='\033[0m'

clear

if [ -e build-anykernel.cfg ]
then
echo "Reading config...." >&2
source "$PWD/build-anykernel.cfg"
else
echo "Configure File is missing..."
exit
fi

# Resources
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"
KERNEL="zImage"
DTBIMAGE="dtb"


# Kernel Details
VER="$VER" >&2
REV="$REV" >&2
DEVICES="$DEVICES" >&2
#BDATE=$(date +"%Y%m%d")
KVER="$KVER" >&2
TestBuild=0


export ERROR_LOG=ERRORS
export LOCALVERSION=$LOCALVERSION
export CROSS_COMPILE=$CROSS_COMPILE
export CHAIN=$CHAIN
export ARCH=$ARCH
export SUBARCH=$SUBARCH
export KBUILD_BUILD_USER=$KBUILD_BUILD_USER
export KBUILD_BUILD_HOST=$KBUILD_BUILD_USER
export CCACHE=$CCACHE
#export ERROR_LOG=$ERROR_LOG

##################################################################
## PATHS ## 
KERNEL_DIR="$KERNEL_DIR" >&2
REPACK_DIR="$REPACK_DIR" >&2
PATCH_DIR="$PATCH_DIR" >&2
MODULES_DIR="$MODULES_DIR" >&2
TOOLS_DIR="$TOOLS_DIR" >&2
RAMDISK_DIR="$RAMDISK_DIR" >&2
RAMDISK_KraKen_DIR="$RAMDISK_KraKen_DIR" >&2
DEFCONFIGS="$DEFCONFIGS" >&2
ZIP_MOVE="$ZIP_MOVE" >&2
COPY_ZIP="$COPY_ZIP" >&2
ZIMAGE_DIR="$ZIMAGE_DIR" >&2
##################################################################

# Functions

## Clean everything that is left over ##
function clean_all {
		rm -rf $MODULES_DIR/*
		cd $REPACK_DIR
		rm -rf $KERNEL
		rm -rf $DTBIMAGE
		echo "Deleting ramdisk Files From $REPACK_DIR"
		rm -rf *.zip
		cd $KERNEL_DIR
		echo "Deleting arch/arm/boot/*.dtb's"
		rm -rf arch/arm/boot/*dtb
		echo "Deleting arch/arm/boot/zImage*"
		rm -rf arch/arm/boot/zImage*
		echo "Deleting arch/arm/boot/Image*"
		rm -rf arch/arm/boot/Image*
		echo
		make clean && make mrproper
}

function set_timestamp() {
#BDATE=$(date +"%Y%m%d")
KVER="$KVER" >&2
}

## Change Variant in anykernel.sh file ##
function change_variant {
		TAG=$VARIANT
		if [ "$VARIANT" == "d855_lowmem" ]; then TAG="d855"
		echo "TAG1: $TAG"
		fi
		echo "TAG: $TAG"
		cd $REPACK_DIR
		sed -i '12s/.*/device.name1='$TAG'/' anykernel.sh
		sed -i '13s/.*/device.name2=LG-'$TAG'/' anykernel.sh
		cd $KERNEL_DIR
		#cd $REPACK_DIR
        #sed -i 's/d850/$VARIANT/g; s/d851/$VARIANT/g; s/d852/$VARIANT/g; s/d855/$VARIANT/g; s/f400/$VARIANT/g; s/ls990/$VARIANT/g; s/vs985/$VARIANT/g/g' anykernel.sh
		#UP_CASE=$VARIANT | tr '[:upper:]' '[:lower:]'
		#sed -i 's/D850/$VARIANT/g; s/D851/$VARIANT/g; s/D852/$VARIANT/g; s/D855/$VARIANT/g; s/F400/$VARIANT/g; s/LS990/$VARIANT/g; s/VS985/$VARIANT/g/g' anykernel.sh
		#cd $KERNEL_DIR
}

function show_log {
rm -f build.log; echo Initialize log >> build.log
  date >> build.log
  tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
  trap 'rm -f $tempfile; stty sane; exit 1' 1 2 3 15
  dialog --title "TAIL BOXES" \
        --begin 10 10 --tailboxbg build.log 8 58 \
        --and-widget \
        --begin 3 10 --msgbox "Press OK " 5 30 \
        2>$tempfile &
  mypid=$!
  for i in 1 2 3;  do echo $i >> build.log; sleep 1; done
  echo Done. >> build.log
  wait $mypid
  rm -f $tempfile
}

## Build Log ##  
function build_log {
		rm -rf build.log
		if [ "$ERROR_LOG" == "ERRORS" ]; then
        exec 2> >(sed -r 's/'$(echo -e "\033")'\[[0-9]{1,2}(;([0-9]{1,2})?)?[mK]//g' | tee -a build.log)
		fi
		if [ "$ERROR_LOG" == "FULL" ]; then
        exec &> >(tee -a build.log)
		fi
}


## Logging options ##
function menu_log {
DIALOG=${DIALOG=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

$DIALOG --backtitle "Logging Options" \
	--title "Menu: Logging Options" --clear \
        --radiolist "Choose your Logging Option below" 20 61 5 \
        "Errors"  "Log only compile errors" on \
        "Full"    "Full logging" off \
        "Off" "Off: No Logging at all" off  2> $tempfile
# 0 = No Log
# 1 = FULL
# 2 = Errors Only

retval=$?

choice=`cat $tempfile`
case $retval in
  0)
	if [ "$choice" == "Errors" ]; then
	echo "Log set to Errors Only"
	export ERROR_LOG=ERRORS
	fi
	if [ "$choice" == "Full" ]; then
	echo "Log Full On"
	export ERROR_LOG=FULL
	fi
	if [ "$choice" == "Off" ]; then
	echo "Log If off"
	export ERROR_LOG=OFF
	fi
	build_log;;
  1)
    echo "Cancel pressed.";;
  255)
    echo "ESC pressed.";;
esac
}


## Pipe Output to Dialog Box ##
function pipe_output() {
	exec &> >(tee -a screen.log)
	dialog --title "$title" --tailbox screen.log 25 140
}


## Get Size Of Filename and Check it ##
function check_filesize() {
	minsize=3
	maxsize=18
	cd $ZIP_MOVE
	file="Kraken_Nougat_""$REV""_""$VARIANT""_""$KVER"".zip"
	actualsize=$(du -k "$file" | cut -f 1)
	if [ $actualsize -ge $maxsize ]; then
    echo size is over $maxsize kilobytes
	else
    echo size is under $minimumsize kilobytes
	echo Size is: $actualsize
fi
}

## Bump all Defconfigs ##
function bump_defconfigs() {
	dialog --inputbox \
		"Enter Version NFO:" 0 0 2> /tmp/inputbox.tmp.$$
		retval=$?
		input=`cat /tmp/inputbox.tmp.$$`
		rm -f /tmp/inputbox.tmp.$$
			if [ -z "$input" ]; then
			echo "String is empty"
			exit
			fi
		case $retval in
		0)
		BUMP_REV="$input"
		OLD_REV="$REV"
		REV="$input";;
		1)
		echo "Cancel pressed.";;
		esac
		replace_string $REPACK_DIR/anykernel.sh "kernel.string" "Rev$OLD_REV" "Rev$REV"
		replace_string $KERNEL_DIR/build-anykernel.cfg "REV" "$OLD_REV" "$REV"
		OIFS=$IFS
		IFS=';'
		arr2=$DEVICES
		for x in $arr2
		do
		DEFCONFIG="${x}_defconfig"
		cd $DEFCONFIGS
		sed -i '9s/.*/CONFIG_LOCALVERSION="-KraKen_Rev'$BUMP_REV'"/' $DEFCONFIG
		
		cd $KERNEL_DIR
done

IFS=$OIFS
TITLE="Version Bumped"
BACKTITLE="Version Bumped"
INFOBOX="Bumped to Version $BUMP_REV"
message
}


#######################################################
# COMMANDS USED FOR STRINGS                           #
#######################################################

# backup_file <file>
backup_file() { cp $1 $1~; }

# remove_file <file>
remove_file() { rm -rf $1~; }

# replace_string <file> <if search string> <original string> <replacement string>
replace_string() {
  if [ -z "$(grep -q "$2" $1)" ]; then
  echo Found: "$1; $2; $3; $4"
      sed -i "s;${3};${4};" $1;
      echo "Match Found"
  fi;
}

# replace_section <file> <begin search string> <end search string> <replacement string>
replace_section() {
  line=`grep -n "$2" $1 | cut -d: -f1`;
  sed -i "/${2}/,/${3}/d" $1;
  sed -i "${line}s;^;${4}\n;" $1;
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  sed -i "/${2}/,/${3}/d" $1;
}

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>
insert_line() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;${5}\n;" $1;
  fi;
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}s;.*;${3};" $1;
  fi;
}

# remove_line <file> <line match string>
remove_line() {
  if [ ! -z "$(grep "$2" $1)" ]; then
    line=`grep -n "$2" $1 | cut -d: -f1`;
    sed -i "${line}d" $1;
  fi;
}

# prepend_file <file> <if search string> <patch file>
prepend_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo "$(cat $patch/$3 $1)" > $1;
  fi;
}

# insert_file <file> <if search string> <before|after> <line match string> <patch file>
insert_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac;
    line=$((`grep -n "$4" $1 | cut -d: -f1` + offset));
    sed -i "${line}s;^;\n;" $1;
    sed -i "$((line - 1))r $patch/$5" $1;
  fi;
}

# append_file <file> <if search string> <patch file>
append_file() {
  if [ -z "$(grep "$2" $1)" ]; then
    echo -ne "\n" >> $1;
    cat $patch/$3 >> $1;
    echo -ne "\n" >> $1;
  fi;
}

# replace_file <file> <permissions> <patch file>
replace_file() {
  cp -pf $patch/$3 $1;
  chmod $2 $1;
}

# patch_fstab <fstab file> <mount match name> <fs match type> <block|mount|fstype|options|flags> <original string> <replacement string>
patch_fstab() {
  entry=$(grep "$2" $1 | grep "$3");
  if [ -z "$(echo "$entry" | grep "$6")" ]; then
    case $4 in
      block) part=$(echo "$entry" | awk '{ print $1 }');;
      mount) part=$(echo "$entry" | awk '{ print $2 }');;
      fstype) part=$(echo "$entry" | awk '{ print $3 }');;
      options) part=$(echo "$entry" | awk '{ print $4 }');;
      flags) part=$(echo "$entry" | awk '{ print $5 }');;
    esac;
    newentry=$(echo "$entry" | sed "s;${part};${6};");
    sed -i "s;${entry};${newentry};" $1;
  fi;
}


## end methods
#######################################################

## Unversal Message Box ##
## $TITLE = The Title
## $BACKTITLE = The Back Title
## $INFOBOX = Message you want displayed
function message() {
	dialog --title  "$TITLE"  --backtitle  "$BACKTITLE" \
	--infobox  "$INFOBOX" 7 65 ; read 
}


function menu_settings() {
		echo "Test1: $TestBuild"
		if [ $TestBuild == '1' ]; then
			echo "This worked:" 
			#cp Kraken_Nougat_"$REV"_"$VARIANT"_"$KVER".zip $COPY_ZIP
			else
			echo "Didnt Work" 
		fi
			exit		
}

## Batch Build ##
function build_all() {
		OIFS=$IFS
		IFS=';'
		arr2=$DEVICES
		for x in $arr2
		do
		VARIANT="$x"
		DEFCONFIG="${x}_defconfig"
		echo "Device: $VARIANT defconfig: $DEFCONFIG"
		clean_all
		build_log
		change_variant
		make_kernel
		make_dtb
		make_modules
		make_zip
done

IFS=$OIFS

echo -e "${green}"
echo "--------------------------------------------------------"
echo "Created Successfully.."
echo "Builds Completed in:"
echo "--------------------------------------------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
unset ERROR_LOG
exit
}

function make_kernel {
		echo
		make $DEFCONFIG
		make $THREAD
		cp -vr $ZIMAGE_DIR/$KERNEL $REPACK_DIR
}

function make_modules {
		rm `echo $MODULES_DIR"/*"`
		find $KERNEL_DIR -name '*.ko' -exec cp -v {} $MODULES_DIR \;
}

function make_dtb {
		$REPACK_DIR/tools/dtbToolCM -2 -o $REPACK_DIR/$DTBIMAGE -s 2048 -p scripts/dtc/ arch/arm/boot/
}

function make_zip {
		cp -vr $RAMDISK_KraKen_DIR $REPACK_DIR
		cd $REPACK_DIR
		zip -r9 Kraken_Nougat_"$REV"_"$VARIANT"_"$KVER".zip *
		mv Kraken_Nougat_"$REV"_"$VARIANT"_"$KVER".zip $ZIP_MOVE
		rm -rf Kraken_Nougat_"$REV"_"$VARIANT"_"$KVER".zip
		cd $KERNEL_DIR
}


## Finished Build Displayed in a Dialog nfo box ##
function finished_build {
	DATE_END=$(date +"%s")
	DIFF=$(($DATE_END - $DATE_START))
	check_filesize
		if [ -e $ZIMAGE_DIR/$KERNEL ]; then
	dialog --title  "Build Finished"  --backtitle  "Build Finished" \
	--infobox  "Kraken_Nougat_'$REV'_'$VARIANT'_'$KVER'.zip \n\
	Created Successfully..\n\
	FileSize: $actualsize kb \n\
    Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds." 7 65 ; read 
	else
dialog --title  "Build Not Completed"  --backtitle  "Build Had Errors" \
	--infobox  "Build Aborted Do to errors, zImage doesnt exist,\n\
	Unsuccessful Build.." 7 65 ; read
	cd $ZIP_MOVE
	rm -rf Kraken_Nougat_"$REV"_"$VARIANT"_"$KVER".zip
	cd $KERNEL_DIR
	fi
}

DATE_START=$(date +"%s")

function build_kernels {
echo -e "${green}"
echo "Kraken_Nougat Creation Script:"
echo -e "${restore}"

## Build Menu ##
cmd=(dialog --keep-tite --menu "Select options:" 22 76 16)

options=(1 "D850"
         2 "D851"
         3 "D855"
		 4 "ls990"
		 5 "vs985")
 
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

for choice in $choices
do
    case $choice in
        1)
			VARIANT="d850"
			DEFCONFIG="kraken_d850_defconfig"
			break;;
        2)  echo "LG G3 D851 Device Picked."
            VARIANT="d851"
			DEFCONFIG="kraken_d851_defconfig"
			break;;
        3)
		    VARIANT="d855"
		    DEFCONFIG="kraken_d855_defconfig"
		    break;;

		4)
			VARIANT="ls990"
			DEFCONFIG="kraken_ls990_defconfig"
			break;;
		5)
			VARIANT="vs985"
			DEFCONFIG="kraken_vs985_defconfig"
			break;;
		6) build_all
			break;;
		
    esac

done

## Clean Left over Garbage Files Y/N ##
dialog --title "Clean Garbage Files" \
	--backtitle "Clean Junk From Build Dir" \
	--yesno "Do you want to clean garbage files ? \n\
	Its a good idea do say yes here.." 7 60
 
	# Get exit status
	# 0 means user hit [yes] button.
	# 1 means user hit [no] button.
	# 255 means user hit [Esc] key.
	response=$?
	case $response in
	0) clean_all
	   buildkernel_msg;;
	1) echo "No Change";;
	255) echo "[ESC] key pressed.";;
esac

##  Build Kernel Y/N ##
dialog --title "Build Kernel" \
	--backtitle "Linux Shell Script Tutorial Example" \
	--yesno "You are about to Build Kernel For $VARIANT, \n\
	Are you sure you want to build Kernel ?" 7 60
 
	# Get exit status
	# 0 means user hit [yes] button.
	# 1 means user hit [no] button.
	# 255 means user hit [Esc] key.
	response=$?
	case $response in
	0) 	build_log
		change_variant
		make_kernel
		make_dtb
		make_modules
		make_zip
		finished_build;;
	1) echo "File not deleted.";;
	255) echo "[ESC] key pressed.";;
esac
}

 function main_menu() {
while true
do

### display main menu ###
dialog --clear  --help-button --backtitle "Linux Shell Script Tutorial" \
--title "[ M A I N - M E N U ]" \
--menu "You can use the UP/DOWN arrow keys, the first \n\
letter of the choice as a hot key, or the \n\
number keys 1-5 to choose an option.\n\
Choose the TASK" 23 60 15 \
	"Build" "Build Kernels" \
	"Clean"	"Clean Builds" \
	"TC" "Tool Chain TC: $CHAIN" \
	"Log" "Logging Options [Log: $ERROR_LOG]" \
	"Ccache" "Clear Ccache" \
	"Bump" "Bump Version" \
	"Settings" "Settings" \
	"Test" "Testing Stage Area" \
	"2Test" "Test 2" \
	"Exit" "Exit to the shell" 2>"${INPUT}"
 
	menuitem=$(<"${INPUT}")
 
 
# make decsion 
case $menuitem in
		Build) build_kernels ;;
		Clean) clean_all ;;
		TC) echo "Not Implanted yet" ;;
		Log) menu_log ;;
		Ccache) echo "Clearing Ccache.."; rm -rf ${HOME}/.ccache ;;
		Bump) bump_defconfigs ;;
		Settings) menu_settings ;;
		Test) file=build-anykernel.sh; check_filesize ;;
		2Test) echo "kernel: $KERNEL_DIR and $ZIMAGE_DIR"; exit ;;
		Exit) echo "Bye"; exit;;
		Cancel) exit ;;
		255) echo "Cancel"; exit;;
esac
 
 done
}

#### Main Menu Start ####
main() {
	set_timestamp
    main_menu
}

echo -e "${green}"
echo "--------------------------------------------------------"
echo "Kraken_Nougat_'$REV'_'$VARIANT'_'$KVER'-signed.zip"
echo "Created Successfully.."
echo "Build Completed in:"
echo "--------------------------------------------------------"
echo -e "${restore}"

DATE_END=$(date +"%s")
DIFF=$(($DATE_END - $DATE_START))
echo "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
echo

# if temp files found, delete em
[ -f $OUTPUT ] && rm $OUTPUT
[ -f $INPUT ] && rm $INPUT
unset ERROR_LOG
main "$@"
