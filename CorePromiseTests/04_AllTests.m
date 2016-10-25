@import Foundation;
#import <CorePromise/CorePromise.h>
@import XCTest;


@interface AllTests: XCTestCase @end

@implementation AllTests

- (void)test_56_empty_array_all {
    id ex1 = [self expectationWithDescription:@""];

    CorePromiseAll(@[]).then(^id(NSArray *array){
        XCTAssertEqual(array.count, 0ul);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_57_empty_array_all {
    id ex1 = [self expectationWithDescription:@""];

    CorePromiseAll(@[]).then(^id(NSArray *array){
        XCTAssertEqual(array.count, 0ul);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_18_all {
    id ex1 = [self expectationWithDescription:@""];

    id a = CorePromiseAfter(0.02).then(^id(id nop){ return @345; });
    id b = CorePromiseAfter(0.03).then(^id(id nop){ return @345; });
    CorePromiseAll(@[a, b]).then(^id(NSArray *objs){
        XCTAssertEqual(objs.count, 2ul);
        XCTAssertEqualObjects(objs[0], objs[1]);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_21_recursive_all {
    id domain = @"sdjhfg";

    id ex1 = [self expectationWithDescription:@""];
    id a = CorePromiseAfter(0.03).then(^id(id nop){
        return [NSError errorWithDomain:domain code:123 userInfo:nil];
    });
    id b = CorePromiseAfter(0.02);
    id c = CorePromiseAll(@[a, b]);
    CorePromiseAll(@[c]).then(^id(id nop){
        [ex1 fulfill];
        return nil;
    }).catch(^id(NSError *e){
        XCTFail();
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_22_already_resolved_and_bubble {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];

    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver  _Nonnull resolver) {
        resolver([NSError errorWithDomain:@"a" code:1 userInfo:nil]);
    }];

    promise.then(^id(id nop){
        XCTFail();
        return nil;
    }).catch(^id(NSError *e){
        [ex1 fulfill];
        return nil;
    });

    CorePromiseAll(@[promise]).then(^id(id nop){
        [ex2 fulfill];
        return nil;
    }).catch(^id(NSError* error){
        XCTFail();
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_24_some_edge_case {
    id ex1 = [self expectationWithDescription:@""];
    id a = CorePromiseAfter(0.02).catch(^id(id nop){return nil;});
    id b = CorePromiseAfter(0.03);
    CorePromiseAll(@[a, b]).then(^id(NSArray *objs){
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_35_all_nil {
    id ex1 = [self expectationWithDescription:@""];

    CPPromise *promise = [CPPromise promiseWithValue:@"35"].then(^id(id nop){ return nil; });
    CorePromiseAll(@[CorePromiseAfter(0.02).then(^id(id nop){ return @1; }), [CPPromise promiseWithValue:nil], promise]).then(^id(NSArray *results){
        XCTAssertEqual(results.count, 3ul);
        XCTAssertEqualObjects(results[1], [NSNull null]);
        [ex1 fulfill];
        return nil;
    }).catch(^id(NSError *err){
        abort();
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_41_all_with_repeated_promises {
    id ex1 = [self expectationWithDescription:@""];

    id p = CorePromiseAfter(0.02);
    id v = [CPPromise promiseWithValue:@1];
    CorePromiseAll(@[p, v, p, v]).then(^id(NSArray *aa){
        XCTAssertEqual(aa.count, 4ul);
        XCTAssertEqualObjects(aa[1], @1);
        XCTAssertEqualObjects(aa[3], @1);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_45_all_which_returns_void {
    id ex1 = [self expectationWithDescription:@""];

    CPPromise *promise = [CPPromise promiseWithValue:@1].then(^id(id nop){return nil;});
    CorePromiseAll(@[promise, [CPPromise promiseWithValue:@1]]).then(^id(NSArray *stuff){
        XCTAssertEqual(stuff.count, 2ul);
        XCTAssertEqualObjects(stuff[0], [NSNull null]);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
