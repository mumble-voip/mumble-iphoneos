#!/bin/bash

# builds plcrashutil from source and installs
# it into $HOME/bin as mumble-ios-plcrashutil

ROOT=$(mktemp -d -t plcrashutil)/src
mkdir -p ${ROOT}

svn checkout http://plcrashreporter.googlecode.com/svn/trunk/ ${ROOT}

cd ${ROOT}
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
	-project CrashReporter.xcodeproj -target plcrashutil build

mkdir -p ${HOME}/bin
cp ${ROOT}/build/Release-MacOSX/plcrashutil \
	${HOME}/bin/mumble-ios-plcrashutil

rm -rf ${ROOT}
