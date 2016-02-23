//
//  Promise+UIKit.m
//  Promises
//
//  Created by Alexander Cohen on 2016-02-22.
//  Copyright © 2016 X-Rite, Inc. All rights reserved.
//

#import "Promise+UIKit.h"
#import "Promise.h"

@interface UIViewAnimationPromise : Promise
@end

@implementation UIViewAnimationPromise
@end

@implementation UIView (Promise)

+ (Promise*)promiseAnimateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations
{
    Promise* p = [UIViewAnimationPromise pendingPromise];
    [self animateWithDuration:duration delay:delay options:options animations:animations completion:^(BOOL finished) {
        [p markStateWithValue:@(finished)];
    }];
    return p;
}

+ (Promise*)promiseAnimateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    Promise* p = [UIViewAnimationPromise pendingPromise];
    [self animateWithDuration:duration animations:animations completion:^(BOOL finished) {
        [p markStateWithValue:@(finished)];
    }];
    return p;
}

- (Promise*)promiseSpringAnimationWithMass:(CGFloat)mass stiffness:(CGFloat)stiffness damping:(CGFloat)damping initialVelocity:(CGFloat)initialVelocity forKeyPath:(NSString*)keyPath fromValue:(NSValue*)fromValue toValue:(NSValue*)toValue
{
    CASpringAnimation* spring = [CASpringAnimation animationWithKeyPath:keyPath];
    spring.mass = mass;
    spring.stiffness = stiffness;
    spring.damping = damping;
    spring.initialVelocity = initialVelocity;
    spring.fromValue = fromValue ? fromValue : [self.layer valueForKeyPath:keyPath];
    spring.toValue = toValue;
    spring.duration = spring.settlingDuration;
    
    // tell the model where it actually ends up ( this is so the layer does not bounce back to the original position )
    [self.layer setValue:toValue forKeyPath:keyPath];
    
    UIViewAnimationPromise* p = [UIViewAnimationPromise pendingPromise];
    
    [CATransaction begin];
    
    [CATransaction setCompletionBlock:^{
        [p markStateWithValue:self];
    }];
    
    [self.layer addAnimation:spring forKey:@"promise_spring"];
    
    [CATransaction commit];
    
    return p;
}

@end
