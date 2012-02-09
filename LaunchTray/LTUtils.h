//
//  LTUtils.h
//  LaunchTray
//
//  Created by Dave Heaton on 12-02-08.
//  Copyright (c) 2012 David Heaton. All rights reserved.
//

#ifndef LaunchTray_LTUtils_h
#define LaunchTray_LTUtils_h

#define isnil(x) (x == nil || (id)x == [NSNull null])
#define SafeRelease(x) [x release]; x = nil;

#endif
