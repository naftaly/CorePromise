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

#import <Foundation/Foundation.h>

/* error domain when errors come from CorePromise */
FOUNDATION_EXTERN NSString* const PromiseErrorDomain;

/* NSError.userInfo key if an exception is raised in a handler */
FOUNDATION_EXTERN NSString* const PromiseErrorExceptionKey;

typedef NS_ENUM(NSUInteger,PromiseErrorCode) {
    PromiseErrorCodeNone,
    PromiseErrorCodeException
} NS_ENUM_AVAILABLE(10_11, 9_0);

NS_CLASS_AVAILABLE(10_11,9_0) @interface Promise<__covariant ValueType> : NSObject

typedef Promise*(^PromiseHandler)( id (^)(ValueType obj) );
typedef Promise*(^PromiseOnHandler)( NSOperationQueue*, id (^)(ValueType obj) );

@property (nonatomic,copy,readonly) PromiseOnHandler thenOn;
@property (nonatomic,copy,readonly) PromiseHandler then;
@property (nonatomic,copy,readonly) PromiseHandler error;
@property (nonatomic,copy,readonly) PromiseHandler finally;

/* a promise is resolved when value != nil */
@property (nonatomic,readonly) id/* ValueType */ value;

/* creates a promise in a pending state. call markStateWithValue: when you are ready */
+ (instancetype)pendingPromise;

/* creates a fulfilled promised with a nil value */
+ (instancetype)promise;

/* creates a fulfilled/rejected promised with a value of 'value' */
+ (instancetype)promiseWithValue:(id)value;

/* mark a promise as fulfilled or rejected. if value is an NSError, the promise is rejected. */
- (void)markStateWithValue:(id)value;

/* debugging faciity to name a promise */
@property (nonatomic,copy) NSString* name;

/* the root promise in this chain */
@property (nonatomic,readonly) Promise* root;

/* the parent promise */
@property (nonatomic,weak,readonly) Promise* parent;

@end









