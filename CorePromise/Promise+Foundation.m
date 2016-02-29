/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2016 Alexander Cohen
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "Promise+Foundation.h"
#import "Promise.h"

@implementation NSURLSession (Promise)

+ (Promise*)promiseWithURL:(NSURL*)URL
{
    return [[NSURLSession sharedSession] promiseWithURL:URL];
}

+ (Promise*)promiseWithURLRequest:(NSURLRequest*)request
{
    return [[NSURLSession sharedSession] promiseWithURLRequest:request];
}

- (Promise*)promiseWithURL:(NSURL*)URL
{
    Promise* p = [Promise pendingPromise];
    
    [[self dataTaskWithURL:URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [p markStateWithValue: error ? error : data];
        }];
    }] resume];
    
    return p;
}

- (Promise*)promiseWithURLRequest:(NSURLRequest*)request
{
    Promise* p = [Promise pendingPromise];
    
    [[self dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [p markStateWithValue: error ? error : data];
        }];
    }] resume];
    
    return p;
}

@end

@implementation NSTimer (Promise)

+ (Promise*)promiseScheduledTimerWithTimeInterval:(NSTimeInterval)ti
{
    Promise* p = [Promise pendingPromise];
    [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(_promise_timer_fired:) userInfo:p repeats:NO];
    return p;
}

+ (void)_promise_timer_fired:(NSTimer*)timer
{
    Promise* p = timer.userInfo;
    [p markStateWithValue:nil];
}

@end

@implementation NSFileHandle (Promise)

- (Promise*)promiseRead
{
    [self readInBackgroundAndNotify];
    return [[NSNotificationCenter defaultCenter] promiseObserveOnce:NSFileHandleReadCompletionNotification object:self].then( ^id(NSNotification* note) {
        return note.userInfo[NSFileHandleNotificationDataItem];
    });
}

- (Promise*)promiseReadToEndOfFile
{
    [self readToEndOfFileInBackgroundAndNotify];
    return [[NSNotificationCenter defaultCenter] promiseObserveOnce:NSFileHandleReadToEndOfFileCompletionNotification object:self].then( ^id(NSNotification* note) {
        return note.userInfo[NSFileHandleNotificationDataItem];
    });
}

- (Promise*)promiseWaitForData
{
    [self waitForDataInBackgroundAndNotify];
    return [[NSNotificationCenter defaultCenter] promiseObserveOnce:NSFileHandleDataAvailableNotification object:self].then( ^id(NSNotification* note) {
        return note.object;
    });
}

@end

@implementation NSNotificationCenter (Promise)

- (Promise<NSNotification*>*)promiseObserveOnce:(NSString*)notificationName
{
    return [self promiseObserveOnce:notificationName object:nil];
}

- (Promise<NSNotification*>*)promiseObserveOnce:(NSString*)notificationName object:(id)object
{
    Promise* p = [Promise pendingPromise];
    
    __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:notificationName object:object queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        [p markStateWithValue: note];
    }];

    return p;
}

@end

