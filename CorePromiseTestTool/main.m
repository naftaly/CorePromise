//
//  main.m
//  CorePromiseTestTool
//
//  Created by Alexander Cohen on 2017-10-20.
//  Copyright © 2017 X-Rite, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CorePromiseTools.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        [[CorePromiseTools new] run];
        CFRunLoopRun();
    }
    return 0;
}
