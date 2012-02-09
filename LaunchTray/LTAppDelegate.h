//
//  LTAppDelegate.h
//  LaunchTray
//
//  Created by Dave Heaton on 12-02-08.
//  Copyright (c) 2012 David Heaton. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LTAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>

@property (nonatomic,retain) NSStatusItem *statusItem;
@property (nonatomic,retain) NSMenu *statusMenu;

@property (nonatomic,retain) NSArray *userAgents;

- (void)updateUserAgents;
- (void)updateStatusMenu;

@end
