//
//  main.m
//  promise_tests
//
//  Created by Alexander Cohen on 2016-06-15.
//  Copyright © 2016 X-Rite, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <CorePromise/CorePromise.h>

static void doTests()
{
    [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {

        NSLog( @"--> IN BLOCK" );
        fulfill(@"hello");

    }].then( ^id(id val) {
        
        NSLog( @"--> IN THEN: %@", val );

        return nil;
        
    });

}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        doTests();
        CFRunLoopRun();
    }
    return 0;
}

