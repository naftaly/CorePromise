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

@interface CPProgressDownloadTask : NSObject

@property (nonatomic,strong) NSURL* destinationURL;
@property (nonatomic,strong) NSURL* URL;
@property (nonatomic,copy) NSURLSessionPromiseProgressHandler progressHandler;
@property (nonatomic,copy) CPPromiseFulfiller fulfill;
@property (nonatomic,copy) CPPromiseRejecter reject;
@property (nonatomic,assign) BOOL sentFirstProgress;

@property (nonatomic,strong) NSURLSessionDownloadTask* task;

@end

@implementation CPProgressDownloadTask
@end

@interface CPProgressURLSessionDelegate : NSObject <NSURLSessionDownloadDelegate>

@property (nonatomic,strong) CPProgressDownloadTask* runningTask;
@property (nonatomic,strong) NSRecursiveLock* lock;
@property (nonatomic,strong) NSMapTable* taskTable;

@end

@implementation CPProgressURLSessionDelegate

- (instancetype)init
{
    self = [super init];
    self.taskTable = [NSMapTable strongToStrongObjectsMapTable];
    self.lock = [[NSRecursiveLock alloc] init];
    return self;
}

- (void)addTask:(CPProgressDownloadTask*)task
{
    if ( task )
    {
        [self.lock lock];
        [self.taskTable setObject:task forKey:task.task];
        if ( self.runningTask == nil )
        {
            self.runningTask = task;
            [self.runningTask.task resume];
        }
        [self.lock unlock];
    }
}

- (void)removeTask:(CPProgressDownloadTask*)task
{
    if ( task && [self.taskTable objectForKey:task.task] != nil )
    {
        [self.lock lock];
        [self.taskTable removeObjectForKey:task.task];
        [task.task cancel];
        
        if ( task == self.runningTask )
        {
            self.runningTask = self.taskTable.objectEnumerator.allObjects.firstObject;
            if ( self.runningTask )
                [self.runningTask.task resume];
        }
        
        [self.lock unlock];
    }
}

#pragma mark delegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    [self.lock lock];
    CPProgressDownloadTask* t = [self.taskTable objectForKey:downloadTask];
    NSURLSessionPromiseProgressHandler handler = t.progressHandler;
    NSURL* url = t.URL;
    BOOL first = t.sentFirstProgress;
    t.sentFirstProgress = YES;
    [self.lock unlock];
    
    if ( handler )
    {
        double progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            handler( url, progress, !first );
        }];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    [self.lock lock];
    CPPromiseFulfiller fulfill = nil;
    CPPromiseRejecter reject = nil;
    NSURL* dstURL = nil;
    CPProgressDownloadTask* t = [self.taskTable objectForKey:downloadTask];
    if ( t )
    {
        dstURL = t.destinationURL;
        fulfill = t.fulfill;
        reject = t.reject;
        [self removeTask:t];
    }
    [self.lock unlock];
    
    if ( !dstURL )
        return;
    
    [[NSFileManager defaultManager] removeItemAtURL:dstURL error:nil];
    
    NSError* copyError = nil;
    if ( ![[NSFileManager defaultManager] copyItemAtURL:location toURL:dstURL error:&copyError] )
    {
        if ( reject )
        {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                reject(copyError);
            }];
        }
        return;
    }
    
    if ( fulfill )
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            fulfill(dstURL);
        }];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
    [self.lock lock];
    CPPromiseRejecter reject = nil;
    CPProgressDownloadTask* t = [self.taskTable objectForKey:task];
    if ( t )
    {
        reject = t.reject;
        [self removeTask:t];
    }
    [self.lock unlock];
    
    if ( reject )
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            reject(error);
        }];
    }
}

@end

@implementation NSURLSession (CPPromise)

+ (CPProgressURLSessionDelegate*)_progressDelegate
{
    static CPProgressURLSessionDelegate* del = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        del = [CPProgressURLSessionDelegate new];
    });
    return del;
}

+ (instancetype)cp_progressSession
{
    static NSOperationQueue* queue = nil;
    static NSURLSession* session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        queue = [[NSOperationQueue alloc] init];
        queue.name = @"com.bedroomcode.corepromise.urlsession.progress.queue";
        queue.qualityOfService = NSQualityOfServiceUtility;
        
        
        NSURLSessionConfiguration* config = [[NSURLSessionConfiguration defaultSessionConfiguration] copy];
        config.HTTPMaximumConnectionsPerHost = 1;
        config.timeoutIntervalForRequest = 10;
        
        session = [NSURLSession sessionWithConfiguration:config delegate:[self _progressDelegate] delegateQueue:queue];
    });
    
    return session;
}

+ (CPPromise *)promiseForFileWithURL:(NSURL *)URL destinationURL:(NSURL*)destinationURL progress:(NSURLSessionPromiseProgressHandler)progress;
{
    return [[NSURLSession cp_progressSession] promiseForFileWithURL:URL destinationURL:destinationURL progress:progress];
}

+ (CPPromise*)promiseWithURL:(NSURL*)URL
{
    return [[NSURLSession sharedSession] promiseWithURL:URL];
}

+ (CPPromise*)promiseWithURLRequest:(NSURLRequest*)request
{
    return [[NSURLSession sharedSession] promiseWithURLRequest:request];
}

- (CPPromise *)promiseForFileWithURL:(NSURL *)URL destinationURL:(NSURL*)destinationURL progress:(NSURLSessionPromiseProgressHandler)progress;
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        
        CPProgressDownloadTask* dt = [CPProgressDownloadTask new];
        dt.URL = URL;
        dt.fulfill = fulfill;
        dt.reject = reject;
        dt.progressHandler = progress;
        dt.task = [self downloadTaskWithURL:URL];
        dt.destinationURL = destinationURL;
        [[[self class] _progressDelegate] addTask:dt];
        
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

