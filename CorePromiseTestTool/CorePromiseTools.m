//
//  CorePromiseTools.m
//  CorePromiseTestTool
//
//  Created by Alexander Cohen on 2017-10-20.
//  Copyright © 2017 X-Rite, Inc. All rights reserved.
//

#import "CorePromiseTools.h"

@import CorePromise;

@implementation CorePromiseTools

- (void)run
{
    [CPPromise promise]
    .then(^id _Nullable(id  _Nullable value) {
        @throw @"Hello";
    })
    .error(^id _Nullable(NSError * _Nonnull error) {
        NSLog( @"%@", error );
        return nil;
    });
}

@end
