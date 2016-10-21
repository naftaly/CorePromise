@import Foundation;
#import <CorePromise/CorePromise.h>
@import XCTest;


@interface WhenTests: XCTestCase @end @implementation WhenTests

- (void)testProgress {

    id ex = [self expectationWithDescription:@""];

    XCTAssertNil([NSProgress currentProgress]);

    id p1 = CorePromiseAfter(0.01);
    id p2 = CorePromiseAfter(0.02);
    id p3 = CorePromiseAfter(0.03);
    id p4 = CorePromiseAfter(0.04);

    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    [progress becomeCurrentWithPendingUnitCount:1];

    CorePromiseWhen(@[p1, p2, p3, p4]).then(^id(id nop){
        XCTAssertEqual(progress.completedUnitCount, 1);
        [ex fulfill];
        return nil;
    });

    [progress resignCurrent];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testProgressDoesNotExceed100Percent {

    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];

    XCTAssertNil([NSProgress currentProgress]);

    id p1 = CorePromiseAfter(0.01);
    id p2 = CorePromiseAfter(0.02).then(^id(id nop){ return [NSError errorWithDomain:@"a" code:1 userInfo:nil]; });
    id p3 = CorePromiseAfter(0.03);
    id p4 = CorePromiseAfter(0.04);

    id promises = @[p1, p2, p3, p4];

    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    [progress becomeCurrentWithPendingUnitCount:1];

    CorePromiseWhen(promises).catch(^id(id nop){
        [ex2 fulfill];
        return nil;
    });

    [progress resignCurrent];

    CorePromiseJoin(promises).catch(^id(id nop){
        XCTAssertLessThanOrEqual(1, progress.fractionCompleted);
        XCTAssertEqual(progress.completedUnitCount, 1);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_56_empty_array_when {
    id ex1 = [self expectationWithDescription:@""];

    CorePromiseWhen(@[]).then(^id(NSArray *array){
        XCTAssertEqual(array.count, 0ul);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_57_empty_array_all {
    id ex1 = [self expectationWithDescription:@""];

    CorePromiseWhen(@[]).then(^id(NSArray *array){
        XCTAssertEqual(array.count, 0ul);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_18_when {
    id ex1 = [self expectationWithDescription:@""];

    id a = CorePromiseAfter(0.02).then(^id(id nop){ return @345; });
    id b = CorePromiseAfter(0.03).then(^id(id nop){ return @345; });
    CorePromiseWhen(@[a, b]).then(^id(NSArray *objs){
        XCTAssertEqual(objs.count, 2ul);
        XCTAssertEqualObjects(objs[0], objs[1]);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_21_recursive_when {
    id domain = @"sdjhfg";

    id ex1 = [self expectationWithDescription:@""];
    id a = CorePromiseAfter(0.03).then(^id(id nop){
        return [NSError errorWithDomain:domain code:123 userInfo:nil];
    });
    id b = CorePromiseAfter(0.02);
    id c = CorePromiseWhen(@[a, b]);
    CorePromiseWhen(@[c]).then(^id(id nop){
        XCTFail();
        return nil;
    }).catch(^id(NSError *e){
        XCTAssertEqualObjects(e.userInfo[CorePromiseFailingIndexKey], @0);
        XCTAssertEqualObjects(e.domain, domain);
        [ex1 fulfill];
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

    CorePromiseWhen(@[promise]).then(^id(id nop){
        XCTFail();
        return nil;
    }).catch(^id(NSError* error){
        [ex2 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_24_some_edge_case {
    id ex1 = [self expectationWithDescription:@""];
    id a = CorePromiseAfter(0.02).catch(^id(id nop){return nil;});
    id b = CorePromiseAfter(0.03);
    CorePromiseWhen(@[a, b]).then(^id(NSArray *objs){
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_35_when_nil {
    id ex1 = [self expectationWithDescription:@""];

    CPPromise *promise = [CPPromise promiseWithValue:@"35"].then(^id(id nop){ return nil; });
    CorePromiseWhen(@[CorePromiseAfter(0.02).then(^id(id nop){ return @1; }), [CPPromise promiseWithValue:nil], promise]).then(^id(NSArray *results){
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

- (void)test_41_when_with_repeated_promises {
    id ex1 = [self expectationWithDescription:@""];

    id p = CorePromiseAfter(0.02);
    id v = [CPPromise promiseWithValue:@1];
    CorePromiseWhen(@[p, v, p, v]).then(^id(NSArray *aa){
        XCTAssertEqual(aa.count, 4ul);
        XCTAssertEqualObjects(aa[1], @1);
        XCTAssertEqualObjects(aa[3], @1);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_45_when_which_returns_void {
    id ex1 = [self expectationWithDescription:@""];

    CPPromise *promise = [CPPromise promiseWithValue:@1].then(^id(id nop){return nil;});
    CorePromiseWhen(@[promise, [CPPromise promiseWithValue:@1]]).then(^id(NSArray *stuff){
        XCTAssertEqual(stuff.count, 2ul);
        XCTAssertEqualObjects(stuff[0], [NSNull null]);
        [ex1 fulfill];
        return nil;
    });

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
