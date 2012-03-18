Mumble for iOS (iPhone, iPod touch and iPad)
============================================

This is the source code of Mumble (a gaming-focused social
voice chat utility) for iOS-based devices.

The desktop version of Mumble runs on Windows, Mac OS X, Linux
and various other Unix-like systems. Visit its website at:

 <http://mumble.info/>

Building it
===========

To build this you need Xcode 4 and the latest iOS SDK from Apple.

The easiest way to get a working source tree is to check out
the mumble-iphoneos repository recursively (his will recursively
fetch all submodules), because there are quite a few submodules.

To fetch the repository:

    $ git clone --recursive http://github.com/mumble-voip/mumble-iphoneos.git

Once this is done, you should be able to open up the Xcode
project file for Mumble (Mumble.xcodeproj) in the root of
the source tree and hit Cmd-B to build!

Extra tips for advanced users
=============================

When launching Mumble.xcodeproj for the first time, you're recommended to
remove all schemes but the Mumble one. Xcode will automatically populate
it with the schemes of all .xcodeprojs in the workspace.

Schemes can be configured using the dropdown box right of the start and stop
buttons in the default Xcode 4 UI.

We also recommend you to edit the default scheme for the Mumble target
and change the Archive configuration to BetaDist, and the Test configuration
to Release (debug builds pretty slow for devices, but for the Simulator, they're
OK!)
