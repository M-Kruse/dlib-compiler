#!/bin/bash
#Description: Compile script for dlib on Debian/Ubuntu

CMAKE_THREADS="6"

DLIB_REPO="https://github.com/davisking/dlib.git"

APT_PKGS="libx11-dev libopenblas-dev liblapack-dev cmake git python3-pip python3-distutils python3-setuptools python3-numpy"
PIP_PKGS="setuptools numpy"

PKG_INSTALL_SUCCESS=true

echo "[INFO] Checking installed packages..."

for PKG in $APT_PKGS
	do
		if ! $(dpkg-query -W -f='${Status}' $PKG 2>/dev/null | grep -q "ok installed")
			then
				apt-get install -y $PKG &>/dev/null
				if [[ $? > 0 ]]
					then
			    		echo "[ERROR] Failed to install $PKG. Exiting..."
			    		PKG_INSTALL_SUCCESS=false
					else
				    	echo "[INFO] Successfully installed $PKG..."
				fi
		fi
	done

if $PKG_INSTALL_SUCCESS
	then
		if [ ! -d "./dlib" ]
			then
				git clone -q $DLIB_REPO
				if [[ $? != 0 ]]
					then
			    		echo "[ERROR] Failed to git clone dlib repo. Exiting..."
			    		exit
					else
				    	echo "[INFO] Successfully cloned dlib repo..."
				fi
			else
				echo "[INFO] Dlib Repo already exists, skipping clone operation..."
		fi
		cd dlib/
		if [ ! -d "./build" ]
			then
				mkdir build
		fi
		cd build/
		#lscpu |grep avx

		if [[ $(sudo lscpu | grep avx) ]]
			then
				AVX=1
				echo "[INFO] Compiling with AVX support..."
			else
				echo "[INFO} AVX support not detected from lscpu, skipping..."
				AVX=0
		fi
		if [[ -x `which nvcc` ]]
			then
				CUDA=1
				echo "[INFO] Compiling with CUDA support..."
			else
				CUDA=0
				echo "[INFO] CUDA was not detected, skipping..."
		fi
		echo "[INFO] Creating cmake build files..."
		sudo cmake .. -DDLIB_USE_CUDA=$CUDA -DUSE_AVX_INSTRUCTIONS=$AVX #> /dev/null 2>&1
		if [[ $? > 0 ]]
			then
				echo "[ERROR] Failed to configure cmake for build. Exiting..."
				exit
		fi
		sudo cmake --build . -j $CMAKE_THREADS > /dev/null 2>&1
		if [[ $? > 0 ]]
			then
				echo "[ERROR] Failed to build with cmake. Exiting..."
				exit
		fi
		cd ..	
		sudo python3 setup.py install > /dev/null 2>&1
		if [[ $? > 0 ]]
		then
				echo "[ERROR] Failed to build dlib python library. Exiting..."
				exit
		fi
		echo "[INFO] Cmake build was successful. Building tests... Please wait...."
		#Run tests
		mkdir -p dlib/test/build 
		cd dlib/test/build
		cmake .. > /dev/null 2>&1
		cmake --build . --config Release -j $CMAKE_THREADS > /dev/null 2>&1
		if [[ $? > 0 ]]
		then
				echo "[ERROR] Failed to build dlib test units. Exiting..."
				exit
		fi
		echo "[INFO] Running dlib tests. Please wait..."
		./dtest --runall > /dev/null 2>&1
		if [[ $? > 0 ]]
		then
				echo "[ERROR] Failed to run dlib tests..."
				exit
		else
				echo "[INFO] Tests completed successfully..."
				echo "[INFO] Exiting..."
		fi
		print("[INFO] Running python test...")
		python3 -c 'import dlib; print("[INFO] CUDA Supported: {0}".format(dlib.DLIB_USE_CUDA));print("[INFO] AVX Supported: {0}".format(dlib.USE_AVX_INSTRUCTIONS))'
	else
		echo "[INFO] Package installation failed. Please check output for [ERROR]. Exiting.."
		exit
		
fi