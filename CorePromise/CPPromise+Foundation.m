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

#import "CPPromise+Foundation.h"
#import "CPPromise.h"

@implementation NSURLSession (CPPromise)

+ (CPPromise *)promiseForFileWithURL:(NSURL *)URL destinationURL:(NSURL*)destinationURL
{
    return [[NSURLSession sharedSession] promiseForFileWithURL:URL destinationURL:destinationURL];
}

+ (CPPromise*)promiseWithURL:(NSURL*)URL
{
    return [[NSURLSession sharedSession] promiseWithURL:URL];
}

+ (CPPromise*)promiseWithURLRequest:(NSURLRequest*)request
{
    return [[NSURLSession sharedSession] promiseWithURLRequest:request];
}

- (CPPromise *)promiseForFileWithURL:(NSURL *)URL destinationURL:(NSURL*)destinationURL
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        
        [[self downloadTaskWithURL:URL completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if ( error )
            {
                reject(error);
                return;
            }
            
            [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
            
            NSError* copyError = nil;
            if ( ![[NSFileManager defaultManager] copyItemAtURL:location toURL:destinationURL error:&copyError] )
            {
                reject(copyError);
                return;
            }
            
            fulfill(destinationURL);
            
        }] resume];

    }];
}

- (CPPromise*)promiseWithURL:(NSURL*)URL
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        
        [[self dataTaskWithURL:URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if ( error )
                    reject(error);
                else
                    fulfill(data);
            }];
        }] resume];
        
    }];
}

- (CPPromise*)promiseWithURLRequest:(NSURLRequest*)request
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {

        [[self dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if ( error )
                    reject(error);
                else
                    fulfill(data);
            }];
        }] resume];

    }];
}

@end

@implementation NSTimer (CPPromise)

+ (CPPromise*)promiseScheduledTimerWithTimeInterval:(NSTimeInterval)ti
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ti * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            fulfill(nil);
        });
    }];
}

@end

@implementation NSNotificationCenter (CPPromise)

- (CPPromise*)promiseObserveOnce:(NSString*)notificationName
{
    return [self promiseObserveOnce:notificationName object:nil];
}

- (CPPromise*)promiseObserveOnce:(NSString*)notificationName object:(id)object
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {

        __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:notificationName object:object queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
            fulfill(note);
        }];

    }];

}

@end

