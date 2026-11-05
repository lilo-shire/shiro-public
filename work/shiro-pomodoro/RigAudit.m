#import <Cocoa/Cocoa.h>
#import "ShiroRig.h"
#include <math.h>

static NSData *Frame(ShiroRig *rig, NSInteger row, double time) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:192 pixelsHigh:208 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:192*4 bitsPerPixel:32];
    memset(rep.bitmapData,0,192*208*4);
    NSGraphicsContext *base = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef context = base.CGContext;
    CGContextTranslateCTM(context,0,208); CGContextScaleCTM(context,1,-1);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
    [rig drawRow:row time:time inRect:NSMakeRect(0,0,192,208)];
    [NSGraphicsContext restoreGraphicsState];
    return [NSData dataWithBytes:rep.bitmapData length:192*208*4];
}
static NSInteger RegionChanges(NSData *a, NSData *b, NSRect rect) {
    const unsigned char *x = a.bytes, *y = b.bytes;
    NSInteger changes = 0;
    for (NSInteger row = rect.origin.y; row < NSMaxY(rect); row++) for (NSInteger col = rect.origin.x; col < NSMaxX(rect); col++) {
        NSInteger k = (row*192+col)*4;
        if (memcmp(x+k,y+k,4)) changes++;
    }
    return changes;
}
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) return 2;
        NSImage *atlas = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (!atlas) return 3;
        atlas.size = NSMakeSize(1536,2288);
        ShiroRig *rig = [[ShiroRig alloc] initWithAtlas:atlas];
        NSMutableDictionary *report = [NSMutableDictionary dictionary];
        for (NSArray *spec in @[@[@0,@4.8],@[@3,@9.0],@[@5,@3.6],@[@7,@7.2],@[@8,@3.2]]) {
            NSInteger row = [spec[0] integerValue]; double period = [spec[1] doubleValue];
            NSInteger count = (NSInteger)ceil(period*30), edgePixels = 0, headChanges = 0, feetChanges = 0;
            double sum = 0, maximum = 0;
            NSData *first = nil, *previous = nil;
            CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
            for (NSInteger sample = 0; sample <= count; sample++) {
                @autoreleasepool {
                    double t = period * sample / count;
                    NSData *current = Frame(rig,row,t);
                    if (!first) first = current;
                    const unsigned char *pixels = current.bytes;
                    for (NSInteger y = 0; y < 208; y++) for (NSInteger x = 0; x < 192; x++)
                        if ((x < 2 || x > 189 || y < 2 || y > 205) && pixels[(y*192+x)*4+3] > 32) edgePixels++;
                    feetChanges += RegionChanges(first,current,NSMakeRect(75,194,50,9));
                    if (row == 0 || row == 7) headChanges += RegionChanges(first,current,NSMakeRect(50,25,85,77));
                    if (previous) {
                        const unsigned char *prior = previous.bytes;
                        NSInteger visible = 0, changed = 0;
                        for (NSInteger i = 0; i < 192*208*4; i += 4) {
                            if (pixels[i+3] <= 32 && prior[i+3] <= 32) continue;
                            visible++;
                            NSInteger delta = 0; for (NSInteger c = 0; c < 4; c++) delta += abs(pixels[i+c]-prior[i+c]);
                            if (delta > 56) changed++;
                        }
                        double ratio = visible ? (double)changed/visible : 0;
                        sum += ratio; maximum = fmax(maximum,ratio);
                    }
                    previous = current;
                }
            }
            double duration = CFAbsoluteTimeGetCurrent()-start;
            NSDictionary *begin = [ShiroRig tracksForRow:row time:0], *end = [ShiroRig tracksForRow:row time:period];
            BOOL seamless = YES;
            for (NSString *key in @[@"tail",@"arm",@"lean",@"bug",@"scale",@"feetY"])
                if (fabs([begin[key] doubleValue]-[end[key] doubleValue]) > 1e-8) seamless = NO;
            report[[spec[0] stringValue]] = @{@"frames":@(count+1),@"edgePixels":@(edgePixels),@"headChanges":@(headChanges),@"feetChanges":@(feetChanges),@"meanAdjacentChange":@(sum/count),@"maxAdjacentChange":@(maximum),@"seamlessTracks":@(seamless),@"millisecondsPerFrame":@(duration*1000/(count+1))};
            if (edgePixels || headChanges || feetChanges || !seamless || maximum > 0.2) {
                NSLog(@"Motion invariant failed in row %ld: %@",(long)row,report[[spec[0] stringValue]]);
                NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
                [json writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]; return 4;
            }
        }
        NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
        if (![json writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]) return 5;
        NSLog(@"PASS: native 30fps motion, stationary head/feet, no edge clipping, seamless tracks");
    }
    return 0;
}
