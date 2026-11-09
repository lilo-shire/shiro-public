#import <Cocoa/Cocoa.h>

@interface ShiroRig : NSObject
- (instancetype)initWithDirectory:(NSString *)directory;
- (void)drawRow:(NSInteger)row time:(double)time inRect:(NSRect)rect;
- (NSInteger)frameIndexForRow:(NSInteger)row time:(double)time;
- (double)durationForRow:(NSInteger)row;
- (double)framesPerSecondForRow:(NSInteger)row;
- (NSInteger)frameCountForRow:(NSInteger)row;
@end
