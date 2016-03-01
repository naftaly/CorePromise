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

#import <XCTest/XCTest.h>
#import <CorePromise/CorePromise.h>

@interface CorePromiseTests : XCTestCase

@end

@implementation CorePromiseTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testFulfilledPromise
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Basic expectation"];
    
    [CPPromise promise].then( ^ id (id obj) {
       
        XCTAssertNil(obj);
        [expectation fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        if (error)
            NSLog(@"Timeout Error: %@", error);
    }];
}

- (void)testFulfilledPromiseWithValue
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Basic expectation"];
    
    [CPPromise promiseWithValue:@(1)].then( ^ id (NSNumber* obj) {
        
        XCTAssertNotNil(obj);
        XCTAssertEqual( obj.integerValue, 1);
        [expectation fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        if (error)
            NSLog(@"Timeout Error: %@", error);
    }];
}

- (void)testRejectedPromise
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Basic expectation"];
    
    [CPPromise promiseWithValue:[NSError errorWithDomain:CorePromiseErrorDomain code:1 userInfo:nil]].error( ^ id (NSError* error) {
        
        XCTAssertNotNil(error);
        XCTAssertEqual( error.code, 1 );
        [expectation fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:2 handler:^(NSError * _Nullable error) {
        if (error)
            NSLog(@"Timeout Error: %@", error);
    }];
}

- (void)testChainedPromises
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Basic expectation"];
    
    [CPPromise promise].then( ^ id (id obj) {
        
        XCTAssertNil(obj);
        return @"promised string";
        
    }).then( ^ id (NSString* s) {
       
        XCTAssertNotNil(s);
        XCTAssertEqualObjects(s, @"promised string");
        
        return [NSError errorWithDomain:CorePromiseErrorDomain code:1 userInfo:nil];
        
    }).error( ^id(NSError* error) {
       
        XCTAssertNotNil(error);
        XCTAssertEqual( error.code, 1 );

        return @(10);
        
    }).then( ^ id (NSNumber* num) {
        
        XCTAssertNotNil(num);
        XCTAssertEqualObjects(num, @(10));
        
        return @"bypass error handler";
        
    }).error( ^id(NSError* error) {
        
        XCTAssertTrue(YES);

        return nil;
        
    }).then( ^ id (NSString* bypass) {
        
        XCTAssertNotNil(bypass);
        XCTAssertEqualObjects(bypass, @"bypass error handler");
        
        [expectation fulfill];
        
        return nil;
        
        
    });

    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        if (error)
            NSLog(@"Timeout Error: %@", error);
    }];
}

- (void)testChainedPromisesWithFinally
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Basic expectation"];
    
    [CPPromise promise].then( ^ id (id obj) {
        
        XCTAssertNil(obj);
        return @"promised string";
        
    }).then( ^ id (NSString* s) {
        
        XCTAssertNotNil(s);
        XCTAssertEqualObjects(s, @"promised string");
        
        return [NSError errorWithDomain:CorePromiseErrorDomain code:1 userInfo:nil];
        
    }).error( ^id(NSError* error) {
        
        XCTAssertNotNil(error);
        XCTAssertEqual( error.code, 1 );
        
        return @(10);
        
    }).then( ^ id (NSNumber* num) {
        
        XCTAssertNotNil(num);
        XCTAssertEqualObjects(num, @(10));
        
        return @"bypass error handler";
        
    }).error( ^id(NSError* error) {
        
        XCTAssertTrue(YES);
        
        return nil;
        
    }).then( ^ id (NSString* bypass) {
        
        XCTAssertNotNil(bypass);
        XCTAssertEqualObjects(bypass, @"bypass error handler");

        return @"finally";
        
        
    }).finally( ^id(id obj) {
        
        XCTAssertNotNil(obj);
        XCTAssertEqualObjects(obj, @"finally");
        
        [expectation fulfill];
        return nil;
        
    });
    
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
        if (error)
            NSLog(@"Timeout Error: %@", error);
    }];
}

@end
