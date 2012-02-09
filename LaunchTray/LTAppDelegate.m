//
//  LTAppDelegate.m
//  LaunchTray
//
//  Created by Dave Heaton on 12-02-08.
//  Copyright (c) 2012 David Heaton. All rights reserved.
//

#import "LTAppDelegate.h"


static const NSString *kLTLaunchPath = @"LTLaunchPath";


@implementation LTAppDelegate


@synthesize statusItem = _statusItem;
@synthesize statusMenu = _statusMenu;

@synthesize userAgents = _userAgents;

////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject


- (void)dealloc {
  SafeRelease(_statusMenu);
  SafeRelease(_statusItem);
  SafeRelease(_userAgents);
  [super dealloc];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark - launchd


- (void)launchctl:(NSArray *)arguments status:(int*)status output:(NSString**)output {
  NSTask *task = [[NSTask alloc] init];
  task.launchPath = @"/bin/launchctl";
  task.arguments = arguments;
  
  NSPipe *outputPipe = [NSPipe pipe];
  task.standardOutput = outputPipe;
  
  [task launch];
  
  NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
  
  [task waitUntilExit];
  [task release];
  
  *status = [task terminationStatus];
  *output = [[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease];
}


- (void)loadService:(NSDictionary *)service {
  if (isnil(service)) {
    return;
  }
  
  NSString *path = [service objectForKey:kLTLaunchPath];
  if (isnil(path)) {
    return;
  }

  int status = 0;
  NSString *output = nil;
  [self launchctl:[NSArray arrayWithObjects:@"load", path, nil] status:&status output:&output];

  NSLog(@"loaded %@: (%d) %@", path, status, output);
}


- (void)unloadService:(NSDictionary *)service {
  if (isnil(service)) {
    return;
  }
  
  NSString *path = [service objectForKey:kLTLaunchPath];
  if (isnil(path)) {
    return;
  }
  
  int status = 0;
  NSString *output = nil;
  [self launchctl:[NSArray arrayWithObjects:@"unload", path, nil] status:&status output:&output];
  
  NSLog(@"unloaded %@: (%d) %@", path, status, output);
}


- (BOOL)isServiceRunning:(NSDictionary *)service {
  if (isnil(service)) {
    return NO;
  }
  
  NSString *label = [service objectForKey:@"Label"];
  if (isnil(label)) {
    return NO;
  }
  
  int status = 0;
  NSString *output = nil;
  
  [self launchctl:[NSArray arrayWithObjects:@"list", label, nil] status:&status output:&output];
  
  if (status != 0) {
    return NO;
  }
  
  // TODO examine output as maybe something can be loaded but not running?
  
  return YES;
}


- (void)updateUserAgents {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [@"~/Library/LaunchAgents" stringByExpandingTildeInPath];
  NSError *error = nil;
  
  // List files.
  NSArray *files = [fm contentsOfDirectoryAtPath:path error:&error];
  if (error) {
    [NSApp presentError:error];
    return;
  }
  
  // Load services from files.
  NSMutableArray *services = [NSMutableArray array];
  NSArray *plistFiles = [files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.plist'"]];
  for (NSString *plistFile in plistFiles) {
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:plistFile]];

    if (plist) {
      // Store path in the service plist.
      [plist setObject:[path stringByAppendingPathComponent:plistFile] forKey:kLTLaunchPath];
      
      // Make sure have a label.
      NSString *label = [plist objectForKey:@"Label"];
      if (isnil(label)) {
        [plist setObject:plistFile forKey:@"Label"];
      }
      
      [services addObject:plist];
    }
  }
  
  // Update the user agents list and menu.
  if ([NSThread isMainThread]) {
    self.userAgents = services;
    [self updateStatusMenu];
  } else {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      self.userAgents = services;
      [self updateStatusMenu];
    }];
  }
  [pool release];
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark - Actions


- (void)openService:(NSMenuItem *)sender {
  if (![sender isKindOfClass:[NSMenuItem class]]) {
    return;
  }
  
  NSDictionary *service = [sender representedObject];
  if (![service isKindOfClass:[NSDictionary class]]) {
    return;
  }
  
  BOOL running = [self isServiceRunning:service];
  if (running) {
    [self unloadService:service];
  } else {
    [self loadService:service];
  }
}


//- (void)preferences {
//  // TODO
//}


- (void)exit {
  [[NSApplication sharedApplication] terminate:self];
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark - UI


- (void)updateStatusMenu {
  NSMenu *menu = self.statusMenu;
  NSArray *agents = self.userAgents;

  assert(menu);
  
  [menu removeAllItems];
  
  // User Agents
  if (!isnil(agents)) {
    NSMenuItem *userAgentsItem = [menu addItemWithTitle:@"User Agents:" action:nil keyEquivalent:@""];
    [userAgentsItem setEnabled:NO];
    [menu addItem:[NSMenuItem separatorItem]];
    
    for (NSDictionary *service in agents) {
      BOOL running = [self isServiceRunning:service];

      NSString *label = [service objectForKey:@"Label"];
      NSImage *image = [NSImage imageNamed:@"service-on.png"];
      if (!running) {
        label = [NSString stringWithFormat:@"%@ (stopped)", label];
        image = [NSImage imageNamed:@"service-off.png"];
      }
      
      NSMenuItem *item = [menu addItemWithTitle:label action:@selector(openService:) keyEquivalent:@""];
      item.representedObject = service;
      item.image = image;
      [menu itemChanged:item];
    }
  }
  
  [menu addItem:[NSMenuItem separatorItem]];
//  [menu addItemWithTitle:@"Preferences..." action:@selector(preferences) keyEquivalent:@""];
  [menu addItemWithTitle:@"Quit" action:@selector(exit) keyEquivalent:@""];
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSMenuDelegate


- (void)menuNeedsUpdate:(NSMenu *)menu {
  [self updateUserAgents];
//  [self performSelectorInBackground:@selector(updateUserAgents) withObject:nil];
}


////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSApplicationDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // Create menu.
  self.statusMenu = [[[NSMenu alloc] initWithTitle:@"Services"] autorelease];
  [self.statusMenu setDelegate:self];
  [self updateStatusMenu];
  
  // Create status item.
  NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
  self.statusItem = [statusBar statusItemWithLength:24];
//  [self.statusItem setTitle: NSLocalizedString(@"ld", @"")];
  [self.statusItem setHighlightMode:YES];
  [self.statusItem setMenu:self.statusMenu];
  [self.statusItem setImage:[NSImage imageNamed:@"service-on.png"]];
  
  // Update the user agents in the background.
//  [self performSelectorInBackground:@selector(updateUserAgents) withObject:nil];
}


@end
