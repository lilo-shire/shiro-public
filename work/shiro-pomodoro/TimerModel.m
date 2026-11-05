#import "TimerModel.h"
#include <math.h>

static NSTimeInterval Clamp(NSTimeInterval value, NSTimeInterval fallback, NSTimeInterval limit) {
    if (!isfinite(value)) return fallback;
    return fmax(0, fmin(limit, value));
}

@implementation ShiroTimer
- (instancetype)initWithState:(NSDictionary *)state now:(NSTimeInterval)now {
    if ((self = [super init])) {
        _phase = [state[@"phase"] isEqual:@"break"] ? @"break" : @"work";
        _workSeconds = state[@"workSeconds"] ? [state[@"workSeconds"] doubleValue] : 1200;
        _breakSeconds = state[@"breakSeconds"] ? [state[@"breakSeconds"] doubleValue] : 420;
        if (!isfinite(_workSeconds)) _workSeconds = 1200;
        if (!isfinite(_breakSeconds)) _breakSeconds = 420;
        _workSeconds = fmin(10800, fmax(60, _workSeconds));
        _breakSeconds = fmin(3600, fmax(60, _breakSeconds));
        NSTimeInterval full = [self durationOfPhase:_phase];
        _remaining = state[@"remaining"] ? Clamp([state[@"remaining"] doubleValue], full, full) : full;
        NSString *other = [_phase isEqual:@"work"] ? @"break" : @"work";
        NSTimeInterval otherFull = [self durationOfPhase:other];
        // Version 0.5 had no second slot: the other phase starts fresh.
        _otherRemaining = state[@"otherRemaining"] ? Clamp([state[@"otherRemaining"] doubleValue], otherFull, otherFull) : otherFull;
        if (_otherRemaining <= 0) _otherRemaining = otherFull;
        _deadline = [state[@"deadline"] doubleValue];
        _running = [state[@"running"] boolValue] && isfinite(_deadline) && _deadline > 0;
        if (!_running) _deadline = 0;
        _completed = MAX(0, [state[@"completed"] integerValue]);
    }
    return self;
}
- (NSTimeInterval)durationOfPhase:(NSString *)phase {
    return [phase isEqual:@"break"] ? self.breakSeconds : self.workSeconds;
}
- (NSTimeInterval)remainingAt:(NSTimeInterval)now {
    return self.running ? fmax(0, self.deadline - now) : self.remaining;
}
- (BOOL)isPartialAt:(NSTimeInterval)now {
    return [self remainingAt:now] < [self durationOfPhase:self.phase] - 0.5;
}
- (void)startAt:(NSTimeInterval)now {
    if (self.running) return;
    if (self.remaining <= 0) self.remaining = [self durationOfPhase:self.phase];
    self.deadline = now + self.remaining;
    self.running = YES;
}
- (void)pauseAt:(NSTimeInterval)now {
    if (!self.running) return;
    self.remaining = [self remainingAt:now];
    self.running = NO;
    self.deadline = 0;
}
- (NSString *)tickAt:(NSTimeInterval)now {
    if (!self.running || now < self.deadline) return nil;
    self.running = NO;
    self.deadline = 0;
    if ([self.phase isEqual:@"work"]) {
        self.completed++;
        self.phase = @"break";
        self.remaining = self.breakSeconds;
        self.otherRemaining = self.workSeconds;
        return @"workFinished";
    }
    self.phase = @"work";
    // A focus interval paused by switching to the break continues where it stopped.
    self.remaining = self.otherRemaining > 0 ? self.otherRemaining : self.workSeconds;
    self.otherRemaining = self.breakSeconds;
    return @"breakFinished";
}
- (void)switchToPhase:(NSString *)phase at:(NSTimeInterval)now {
    phase = [phase isEqual:@"break"] ? @"break" : @"work";
    if ([phase isEqual:self.phase]) return;
    [self pauseAt:now];
    NSTimeInterval shown = self.remaining;
    self.remaining = self.otherRemaining > 0 ? self.otherRemaining : [self durationOfPhase:phase];
    self.otherRemaining = shown > 0 ? shown : [self durationOfPhase:self.phase];
    self.phase = phase;
}
- (void)reset {
    self.running = NO;
    self.deadline = 0;
    self.remaining = [self durationOfPhase:self.phase];
}
- (NSTimeInterval)workRemainingAt:(NSTimeInterval)now {
    return [self.phase isEqual:@"work"] ? [self remainingAt:now] : self.otherRemaining;
}
- (void)loadWorkRemaining:(NSTimeInterval)value at:(NSTimeInterval)now {
    NSTimeInterval next = (!isfinite(value) || value <= 0) ? self.workSeconds : fmin(value, self.workSeconds);
    if ([self.phase isEqual:@"work"]) {
        [self pauseAt:now];
        self.remaining = next;
    } else self.otherRemaining = next;
}
- (void)setWorkMinutes:(double)work breakMinutes:(double)rest {
    if (!isfinite(work)) work = 20;
    if (!isfinite(rest)) rest = 7;
    NSTimeInterval oldWork = self.workSeconds, oldBreak = self.breakSeconds;
    self.workSeconds = round(fmin(180, fmax(1, work))) * 60;
    self.breakSeconds = round(fmin(60, fmax(1, rest))) * 60;
    // An untouched slot follows the new length; a started one keeps its time but never exceeds the new length.
    NSTimeInterval (^adjust)(NSTimeInterval, NSTimeInterval, NSTimeInterval) = ^(NSTimeInterval value, NSTimeInterval oldFull, NSTimeInterval newFull) {
        return value >= oldFull - 0.5 ? newFull : fmin(value, newFull);
    };
    BOOL work_ = [self.phase isEqual:@"work"];
    if (!self.running) self.remaining = adjust(self.remaining, work_ ? oldWork : oldBreak, work_ ? self.workSeconds : self.breakSeconds);
    self.otherRemaining = adjust(self.otherRemaining, work_ ? oldBreak : oldWork, work_ ? self.breakSeconds : self.workSeconds);
}
- (NSDictionary *)state {
    return @{@"phase":self.phase, @"running":@(self.running), @"workSeconds":@(self.workSeconds),
             @"breakSeconds":@(self.breakSeconds), @"remaining":@(self.remaining), @"otherRemaining":@(self.otherRemaining),
             @"deadline":@(self.deadline), @"completed":@(self.completed)};
}
@end
