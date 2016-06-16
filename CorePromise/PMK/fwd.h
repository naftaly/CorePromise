#import <Foundation/NSObjCRuntime.h>

@class NSError;
@class NSString;
@class NSOperationQueue;
@class CPPromise;

extern NSOperationQueue *PMKOperationQueue();

#define PMK_DEPRECATED(msg) __attribute__((deprecated(msg)))

#define PMKJSONDeserializationOptions ((NSJSONReadingOptions)(NSJSONReadingAllowFragments | NSJSONReadingMutableContainers))

#define PMKHTTPURLResponseIsJSON(rsp) [@[@"application/json", @"text/json", @"text/javascript"] containsObject:[rsp MIMEType]]
#define PMKHTTPURLResponseIsImage(rsp) [@[@"image/tiff", @"image/jpeg", @"image/gif", @"image/png", @"image/ico", @"image/x-icon", @"image/bmp", @"image/x-bmp", @"image/x-xbitmap", @"image/x-win-bitmap"] containsObject:[rsp MIMEType]]
#define PMKHTTPURLResponseIsText(rsp) [[rsp MIMEType] hasPrefix:@"text/"]

extern void *PMKManualReferenceAssociatedObject;

#define PMKRetain(obj)  objc_setAssociatedObject(obj, PMKManualReferenceAssociatedObject, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC)
#define PMKRelease(obj) objc_setAssociatedObject(obj, PMKManualReferenceAssociatedObject, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC)



#define PMKErrorDomain @"PMKErrorDomain"
#define PMKUnderlyingExceptionKey @"PMKUnderlyingExceptionKey"
#define PMKFailingPromiseIndexKey @"PMKFailingPromiseIndexKey"
#define PMKUnhandledExceptionError 1
#define PMKUnknownError 2
#define PMKInvalidUsageError 3
#define PMKAccessDeniedError 4
#define PMKOperationFailed 5

#define PMKURLErrorFailingURLResponseKey @"PMKURLErrorFailingURLResponseKey"
#define PMKURLErrorFailingDataKey @"PMKURLErrorFailingDataKey"
#define PMKURLErrorFailingStringKey @"PMKURLErrorFailingStringKey"

// deprecated
#define PMKErrorCodeThrown PMKUnhandledExceptionError
#define PMKErrorCodeUnknown PMKUnknownError
#define PMKErrorCodeInvalidUsage PMKInvalidUsageError

extern NSString const * const PMKThrown PMK_DEPRECATED("Use PMKUnderlyingExceptionKey");
