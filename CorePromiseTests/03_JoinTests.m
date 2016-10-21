@import Foundation;
#import <CorePromise/CorePromise.h>
@import XCTest;


@interface JoinTests: XCTestCase @end @implementation JoinTests

- (void)test_73_join {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];

    __block void (^fulfiller)(id) = nil;
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        fulfiller = resolve;
    }];

    CorePromiseJoin(@[
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:1 userInfo:nil]],
              promise,
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:2 userInfo:nil]]
              ]).then(^id(id nop){
        XCTFail();
        return nil;
    }).catch(^id(NSError *error){
        id promises = error.userInfo[CorePromiseJoinPromisesKey];

        int cume = 0, cumv = 0;

        for (CPPromise *promise in promises) {
            if ([promise.value isKindOfClass:[NSError class]]) {
                cume |= [promise.value code];
            } else {
                cumv |= [promise.value unsignedIntValue];
            }
        }

        XCTAssertTrue(cumv == 4);
        XCTAssertTrue(cume == 3);

        [ex1 fulfill];
        return nil;
    });
    fulfiller(@4);
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_74_join_no_errors {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];
    CorePromiseJoin(@[
              [CPPromise promiseWithValue:@1],
              [CPPromise promiseWithValue:@2]
              ]).then(^id(NSArray *values) {
        XCTAssertEqualObjects(values, (@[@1, @2]));
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}


- (void)test_75_join_no_success {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];
    CorePromiseJoin(@[
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:1 userInfo:nil]],
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:2 userInfo:nil]],
              ]).then(^id(id nop){
        XCTFail();
        return nil;
    }).catch(^id(NSError *error){
        XCTAssertNotNil(error);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_76_join_fulfills_if_empty_input {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];
    CorePromiseJoin(@[]).then(^id(id a){
        XCTAssertEqualObjects(@[], a);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
