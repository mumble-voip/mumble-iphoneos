#!/bin/bash
# Sync source code with plcrashreporter SVN

SVNDIR=$1
SRCDIR=${SVNDIR}/Source/

if [ "x$SVNDIR" == "x" ]; then
	echo "usage: sync.bash <svn-repo>"
	exit
fi

classes=\
"CrashReporter
PLCrashSignalHandler
PLCrashFrameWalker
PLCrashFrameWalker_i386
PLCrashFrameWalker_arm
PLCrashLogWriter
PLCrashAsync
PLCrashLogWriterEncoding
PLCrashReporter
PLCrashReport
PLCrashReportSystemInfo
PLCrashReportApplicationInfo
PLCrashReportProcessorInfo
PLCrashReportThreadInfo
PLCrashReportBinaryImageInfo
PLCrashReportExceptionInfo
PLCrashAsyncSignalInfo
PLCrashReportSignalInfo
PLCrashFrameWalker_ppc
PLCrashFrameWalker_x86_64
PLCrashReportProcessInfo
PLCrashReportMachineInfo
PLCrashSysctl
PLCrashReportTextFormatter
PLCrashReportFormatter
PLCrashAsyncImage"

for c in ${classes}; do
	cp ${SRCDIR}/${c}.m ./${c}.m &>/dev/null
	cp ${SRCDIR}/${c}.c ./${c}.c &>/dev/null
	cp ${SRCDIR}/${c}.h ./${c}.h &>/dev/null
done

sed -i '' -e 's,CrashReporter/,,' PLCrashReportTextFormatter.m

cp ${SVNDIR}/Resources/crash_report.proto .
${SVNDIR}/Dependencies/protobuf-2.0.3/bin/protoc-c --c_out=. crash_report.proto
cp ${SVNDIR}/Dependencies/protobuf-2.0.3/src/*.{c,h} .
rm -rf google
mkdir -p google
ln -sf .. google/protobuf-c

cp ${SVNDIR}/LICENSE .
