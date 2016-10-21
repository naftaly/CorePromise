#import <CorePromise/CorePromise.h>
@import XCTest;

@interface HangTests: XCTestCase @end @implementation HangTests

- (void)test {
    __block int x = 0;
    id value = CorePromiseHang(CorePromiseAfter(0.02).then(^id(id nop){ x++; return @1; }));
    XCTAssertEqual(x, 1);
    XCTAssertEqualObjects(value, @1);
}

@end
