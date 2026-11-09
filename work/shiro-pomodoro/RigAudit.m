#import <Cocoa/Cocoa.h>
#import "ShiroRig.h"
#include <math.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) return 2;
        ShiroRig *rig = [[ShiroRig alloc] initWithDirectory:@(argv[1])];
        if (!rig) return 3;
        NSMutableDictionary *report = [NSMutableDictionary dictionary];
        NSInteger total = 0;
        for (NSNumber *key in @[@0,@3,@5,@7,@8]) {
            NSInteger row = key.integerValue, count = [rig frameCountForRow:row], edges = 0;
            double fps = [rig framesPerSecondForRow:row], duration = [rig durationForRow:row];
            if ([rig frameIndexForRow:row time:-1] != 0 || [rig frameIndexForRow:row time:.039] != 0 ||
                [rig frameIndexForRow:row time:.04] != 1) return 4;
            BOOL loop = row == 0 || row == 7;
            if ([rig frameIndexForRow:row time:duration] != (loop ? 0 : count - 1) ||
                [rig frameIndexForRow:row time:duration + .08] != (loop ? 2 : count - 1)) return 5;
            for (NSInteger frame = 0; frame < count; frame++) {
                @autoreleasepool {
                    if ([rig frameIndexForRow:row time:frame/fps] != frame) return 6;
                    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:192 pixelsHigh:208 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:192*4 bitsPerPixel:32];
                    memset(rep.bitmapData,0,rep.bytesPerRow*208);
                    NSGraphicsContext *base = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
                    CGContextRef context = base.CGContext;
                    CGContextTranslateCTM(context,0,208); CGContextScaleCTM(context,1,-1);
                    [NSGraphicsContext saveGraphicsState];
                    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
                    [rig drawRow:row time:frame/fps inRect:NSMakeRect(0,0,192,208)];
                    [NSGraphicsContext restoreGraphicsState];
                    const unsigned char *pixels = rep.bitmapData; NSInteger visible = 0;
                    for (NSInteger y = 0; y < 208; y++) for (NSInteger x = 0; x < 192; x++) {
                        unsigned char alpha = pixels[(y*192+x)*4+3];
                        if (alpha > 0) visible++;
                        if ((x == 0 || x == 191 || y == 0 || y == 207) && alpha > 0) edges++;
                    }
                    if (visible < 1000) return 7;
                    total++;
                }
            }
            report[key.stringValue] = @{@"frames":@(count),@"fps":@(fps),@"seconds":@(duration),@"loop":@(loop),@"edgePixels":@(edges)};
            if (edges) return 8;
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
        if (![data writeToFile:@(argv[2]) atomically:YES]) return 9;
        NSLog(@"PASS: %ld supplied frames; native rendering, timing, transparency and no clipping", (long)total);
    }
    return 0;
}
