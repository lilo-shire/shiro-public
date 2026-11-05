#import <Foundation/Foundation.h>

// One countdown with two slots: the visible phase ("work" or "break") and the other phase,
// whose remaining time is kept in otherRemaining while it is not shown.
@interface ShiroTimer : NSObject
@property(nonatomic, copy) NSString *phase;
@property(nonatomic) BOOL running;
@property(nonatomic) NSTimeInterval workSeconds;
@property(nonatomic) NSTimeInterval breakSeconds;
@property(nonatomic) NSTimeInterval remaining;
@property(nonatomic) NSTimeInterval otherRemaining;
@property(nonatomic) NSTimeInterval deadline;
@property(nonatomic) NSInteger completed;
- (instancetype)initWithState:(NSDictionary *)state now:(NSTimeInterval)now;
- (NSTimeInterval)remainingAt:(NSTimeInterval)now;
- (NSTimeInterval)durationOfPhase:(NSString *)phase;
- (BOOL)isPartialAt:(NSTimeInterval)now;
- (void)startAt:(NSTimeInterval)now;
- (void)pauseAt:(NSTimeInterval)now;
// Returns @"workFinished" or @"breakFinished" once; the next phase always waits for a manual start.
- (NSString *)tickAt:(NSTimeInterval)now;
- (void)switchToPhase:(NSString *)phase at:(NSTimeInterval)now;
- (void)reset;
- (NSTimeInterval)workRemainingAt:(NSTimeInterval)now;
// Loads a saved focus time (a negative value means a fresh interval) and stops the countdown if it shows focus.
- (void)loadWorkRemaining:(NSTimeInterval)value at:(NSTimeInterval)now;
- (void)setWorkMinutes:(double)work breakMinutes:(double)rest;
- (NSDictionary *)state;
@end
