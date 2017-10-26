//
//  AppDelegate.m
//  CorePromiseGUITest
//
//  Created by Alexander Cohen on 2017-10-20.
//  Copyright © 2017 X-Rite, Inc. All rights reserved.
//

#import "AppDelegate.h"

@import CorePromise;

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)_check:(id)sender
{
    NSLog( @"" );
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [CPPromise promise]
    .then(^id _Nullable(id  _Nullable value) {
        @throw @"Hello";
        return nil;
    })
    .error(^id _Nullable(NSError * _Nonnull error) {
        NSLog( @"%@", error );
        return nil;
    });
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
