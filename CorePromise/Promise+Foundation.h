/*
 *
 *  Copyright 2016 X-Rite, Incorporated. All rights reserved.
 *
 *
 *  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 *  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 *  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <CorePromise/Promise.h>

@interface NSURLSession (Promise)

- (Promise<NSData*>*)promiseWithURL:(NSURL*)URL;
- (Promise<NSData*>*)promiseWithURLRequest:(NSURLRequest*)request;

+ (Promise<NSData*>*)promiseWithURL:(NSURL*)URL;
+ (Promise<NSData*>*)promiseWithURLRequest:(NSURLRequest*)request;

@end

@interface NSTimer (Promise)

+ (Promise*)promiseScheduledTimerWithTimeInterval:(NSTimeInterval)ti;

@end

@interface NSFileHandle (Promise)

- (Promise<NSData*>*)promiseRead;
- (Promise<NSData*>*)promiseReadToEndOfFile;
- (Promise<NSFileHandle*>*)promiseWaitForData;

@end

@interface NSNotificationCenter (Promise)

- (Promise<NSNotification*>*)promiseObserveOnce:(NSString*)notificationName;
- (Promise<NSNotification*>*)promiseObserveOnce:(NSString*)notificationName object:(id)object;

@end
