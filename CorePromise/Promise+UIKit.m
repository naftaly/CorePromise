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
