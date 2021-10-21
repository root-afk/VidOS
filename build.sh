#!/bin/bash
BUILDROOT=buildroot-2021.08
BUILDROOT_IMAGE_PATH=$BUILDROOT/$SYSTEM_TYPE_ARG/images/vidos_release
TOOLCHAIN=x86_64-buildroot-linux-musl_sdk-buildroot
SUPPORTED_SYSTEM_TYPES=("av1" "webm")
IS_SUPPORTED=0
#SYSTEM_TYPE_ARG=$1


for SYSTEM_TYPE_ARG in "$@"
do

if [ -z $SYSTEM_TYPE_ARG ]; then
	echo "no configuration specifed, please specify one of the following system types: "${SUPPORTED_SYSTEM_TYPES[@]}&&
	exit 1
fi

for SYSTEM_TYPE in "${SUPPORTED_SYSTEM_TYPES[@]}"
do
	if [ $SYSTEM_TYPE_ARG = $SYSTEM_TYPE ]; then
		IS_SUPPORTED=1
	fi
done

if [ $IS_SUPPORTED = 0 ];then
	echo $SYSTEM_TYPE_ARG" is not a supported configuration, please specify one of the follwing system types: "${SUPPORTED_SYSTEM_TYPES[@]}&&
	exit 1
fi



test -e $BUILDROOT_IMAGE_PATH; BUILDROOT_IMAGE_PATH_EXISTS=$?
if [ $BUILDROOT_IMAGE_PATH_EXISTS -eq 0 ]; then
	VIDOS_ROOTFS=$(ls $BUILDROOT_IMAGE_PATH/ | grep -m 1 "vidos_iso9660_*")
	if [ "$VIDOS_ROOTFS" != "vidos_iso9660_"$SYSTEM_TYPE_ARG ]; then
		yes | rm -r $BUILDROOT
	else
		echo "specified vidos distribution VidOS_"$SYSTEM_TYPE_ARG" has already been built. please run probe.sh"
		exit 0
	fi
fi
echo "building VidOS distribution with "$SYSTEM_TYPE_ARG" support"


test -e $BUILDROOT; BUILDROOT_EXISTS=$?
if [ $BUILDROOT_EXISTS -eq 1 ]; then
	#download and unpack latest buildroot release
	echo "Downloading buildroot version: "$BUILDROOT &&
	wget -qO - https://buildroot.org/downloads/$BUILDROOT.tar.gz | tar zxf - &&
	echo "finished unpacking "$BUILDROOT &&
	#move configuration dir into board dir
	cp -r vidos_av1 $BUILDROOT/board/ &&
	echo "moved vidos_av1 dir to "$BUILDROOT
fi

test -e $TOOLCHAIN; TOOLCHAIN_EXISTS=$?
if [ $TOOLCHAIN_EXISTS -eq 1 ]; then
	test -e $BUILDROOT/$SYSTEM_TYPE_ARG/images/$TOOLCHAIN.tar.gz; TOOLCHAIN_EXISTS=$?
	if [ $TOOLCHAIN_EXISTS -eq 1 ]; then
		echo "Building SDK"
		#move configuration for custom built toolchain (sdk) to .config
		cp sdk_config  $BUILDROOT/$SYSTEM_TYPE_ARG/.config &&
		echo "moved initial SDK configuration to "$BUILDROOT
		cd $BUILDROOT/ &&
		#build a reloacatable toolchain (sdk)
		echo "attempting to build SDK" &&
		make O=$SYSTEM_TYPE_ARG olddefconfig &&
		make O=$SYSTEM_TYPE_ARG -j$(nproc) &&
		make O=$SYSTEM_TYPE_ARG sdk -j$(nproc) &&
		echo "Built SDK sucessfully"
		cd ../
	fi
	#copy and unpack sdk to project root directory
	cp $BUILDROOT/$SYSTEM_TYPE_ARG/images/$TOOLCHAIN.tar.gz ../ &&
	make O=$SYSTEM_TYPE_ARG clean &&
	cd ../ &&
	tar -xf $TOOLCHAIN.tar.gz &&
	rm $TOOLCHAIN.tar.gz &&
	#run relocate-sdk.sh which does funky path nonsense (I think?)
	$TOOLCHAIN/relocate-sdk.sh
fi

test -e $BUILDROOT/$SYSTEM_TYPE_ARG/images/vidos_release; IMAGE_EXISTS=$?
if [ $IMAGE_EXISTS -eq 1 ]; then
	echo "patching base configuration for "$SYSTEM_TYPE_ARG" support" &&
 	patch vidos_base_config vidos_$SYSTEM_TYPE_ARG.patch -o "vidos_"$SYSTEM_TYPE_ARG"_config" &&
	mkdir $BUILDROOT/$SYSTEM_TYPE_ARG &&
	cp "vidos_"$SYSTEM_TYPE_ARG"_config" $BUILDROOT/$SYSTEM_TYPE_ARG/.config &&
	#set toolchain path automagically
	sed -i '6 a BR2_TOOLCHAIN_EXTERNAL_PATH="'$PWD'/'$TOOLCHAIN'"' $BUILDROOT/$SYSTEM_TYPE_ARG/.config &&
	cd $BUILDROOT/ &&
	make O=$SYSTEM_TYPE_ARG olddefconfig &&
	make O=$SYSTEM_TYPE_ARG -j$(nproc)
fi

echo "Build for VidOS_"$SYSTEM_TYPE_ARG" successful!"

done
