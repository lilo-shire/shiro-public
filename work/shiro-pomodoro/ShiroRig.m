#import "ShiroRig.h"
#include <math.h>

@interface ShiroRig ()
@property(nonatomic, copy) NSString *directory;
@property(nonatomic, strong) NSDictionary *clips;
@property(nonatomic, strong) NSCache<NSString *, NSImage *> *atlases;
@property(nonatomic) NSInteger width, height, columns;
@end

@implementation ShiroRig
- (instancetype)initWithDirectory:(NSString *)directory {
    if (!(self = [super init])) return nil;
    NSData *data = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:@"manifest.json"]];
    NSDictionary *manifest = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![manifest isKindOfClass:NSDictionary.class] || [manifest[@"version"] integerValue] != 1) return nil;
    self.directory = directory;
    self.width = [manifest[@"width"] integerValue]; self.height = [manifest[@"height"] integerValue];
    self.columns = [manifest[@"columns"] integerValue]; self.clips = manifest[@"clips"];
    if (self.width != 192 || self.height != 208 || self.columns < 1 || ![self.clips isKindOfClass:NSDictionary.class]) return nil;
    for (NSString *key in @[@"0", @"3", @"5", @"7", @"8"]) {
        NSDictionary *clip = self.clips[key];
        NSString *file = clip[@"file"];
        double fps = [clip[@"fps"] doubleValue];
        if (![file isKindOfClass:NSString.class] || ![file.lastPathComponent isEqual:file] ||
            [clip[@"frames"] integerValue] < 1 || !isfinite(fps) || fps <= 0 || fps > 120 ||
            ![NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:file]]) return nil;
    }
    self.atlases = [[NSCache alloc] init]; self.atlases.countLimit = 2;
    return self;
}
- (NSDictionary *)clipForRow:(NSInteger)row { return self.clips[@(row).stringValue] ?: self.clips[@"0"]; }
- (NSInteger)frameCountForRow:(NSInteger)row { return [[self clipForRow:row][@"frames"] integerValue]; }
- (double)framesPerSecondForRow:(NSInteger)row { return [[self clipForRow:row][@"fps"] doubleValue]; }
- (double)durationForRow:(NSInteger)row { return [self frameCountForRow:row] / [self framesPerSecondForRow:row]; }
- (NSInteger)frameIndexForRow:(NSInteger)row time:(double)time {
    NSDictionary *clip = [self clipForRow:row];
    NSInteger count = [clip[@"frames"] integerValue];
    double fps = [clip[@"fps"] doubleValue], duration = count / fps;
    double elapsed = isfinite(time) ? fmax(0, time) : 0;
    elapsed = [clip[@"loop"] boolValue] ? fmod(elapsed, duration) : fmin(elapsed, duration);
    return MIN(count - 1, (NSInteger)floor(elapsed * fps + 1e-8));
}
- (void)drawRow:(NSInteger)row time:(double)time inRect:(NSRect)rect {
    NSDictionary *clip = [self clipForRow:row];
    NSString *file = clip[@"file"];
    NSImage *atlas = [self.atlases objectForKey:file];
    if (!atlas) {
        atlas = [[NSImage alloc] initWithContentsOfFile:[self.directory stringByAppendingPathComponent:file]];
        NSInteger rows = ([clip[@"frames"] integerValue] + self.columns - 1) / self.columns;
        atlas.size = NSMakeSize(self.width * self.columns, self.height * rows);
        if (atlas) [self.atlases setObject:atlas forKey:file];
    }
    NSInteger index = [self frameIndexForRow:row time:time];
    NSRect source = NSMakeRect((index % self.columns) * self.width,
        atlas.size.height - (index / self.columns + 1) * self.height, self.width, self.height);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
    [atlas drawInRect:rect fromRect:source operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}
@end
