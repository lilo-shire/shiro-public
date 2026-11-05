#import <Cocoa/Cocoa.h>

@interface ShiroRig : NSObject
- (instancetype)initWithAtlas:(NSImage *)atlas;
- (void)drawRow:(NSInteger)row time:(double)time inRect:(NSRect)rect;
+ (NSDictionary *)tracksForRow:(NSInteger)row time:(double)time;
- (BOOL)exportLayersToDirectory:(NSString *)directory error:(NSError **)error;
@end
