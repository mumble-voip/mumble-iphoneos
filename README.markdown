Mumble for iOS (iPhone, iPod touch and iPad)
============================================

This is the source code of Mumble (a gaming-focused social
voice chat utility) for iOS-based devices.

The desktop version of Mumble runs on Windows, Mac OS X, Linux
and various other Unix-like systems. Visit its website at:

 <http://mumble.info/>

Building it
===========

To build this you need the iOS 4.0 SDK from Apple and an
Intel Mac (or equivalent :)) running Mac OS X 10.6 (or later).

The easiest way to get a working source tree is to check out
the mumble-iphoneos repository recursively (his will recursively
fetch all submodules), because there are quite a few submodules.

To fetch the repository:

    $ git clone --recursive http://github.com/mkrautz/mumble-iphoneos.git

Once this is done, you should be able to open up the Xcode
project file for Mumble (Mumble.xcodeproj) in the root of
the source tree and hit Cmd-B to build!
