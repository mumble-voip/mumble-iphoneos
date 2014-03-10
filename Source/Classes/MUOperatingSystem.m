// Copyright 2014 The 'Mumble for iOS' Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "MUOperatingSystem.h"

MUOperatingSystemVersion MUGetOperatingSystemVersion() {
    NSString *iOSVersion = [[UIDevice currentDevice] systemVersion];
    if (iOSVersion) {
        NSArray *iOSVersionComponents = [iOSVersion componentsSeparatedByString:@"."];
        if ([iOSVersionComponents count] > 0) {
            NSInteger majorVersion;
            
            switch (majorVersion) {
                case 5:  return MUMBLE_OS_IOS_5;
                case 6:  return MUMBLE_OS_IOS_6;
                case 7:  return MUMBLE_OS_IOS_7;
                default: {
                    if (majorVersion > 7) {
                        return MUMBLE_OS_IOS_7;
                    }
                }
            }
        }
    }
    
    return MUMBLE_OS_UNKNOWN;
}