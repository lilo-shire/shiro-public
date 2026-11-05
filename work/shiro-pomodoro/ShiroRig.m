#import "ShiroRig.h"
#include <math.h>

@interface RigPose : NSObject
@property(nonatomic, strong) NSImage *body;
@property(nonatomic, strong) NSImage *tail;
@property(nonatomic, strong) NSImage *arm;
@property(nonatomic, strong) NSImage *feet;
@property(nonatomic, strong) NSImage *bug;
@property(nonatomic, strong) NSImage *joints;
@property(nonatomic, strong) NSBezierPath *lenses;
@property(nonatomic) NSPoint tailPivot;
@property(nonatomic) NSPoint armPivot;
@end
@implementation RigPose
@end

@interface ShiroRig ()
@property(nonatomic, strong) NSDictionary<NSNumber *, RigPose *> *poses;
@end

static NSBezierPath *RigPolygon(NSArray<NSArray<NSNumber *> *> *points, double offset) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    for (NSUInteger i = 0; i < points.count; i++) {
        NSPoint point = NSMakePoint(points[i][0].doubleValue, points[i][1].doubleValue + offset);
        if (i) [path lineToPoint:point]; else [path moveToPoint:point];
    }
    [path closePath]; return path;
}
static NSImage *Raster(void (^draw)(void)) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:192 pixelsHigh:208 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(rep.bitmapData,0,rep.bytesPerRow*208);
    NSGraphicsContext *base = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef context = base.CGContext;
    CGContextTranslateCTM(context, 0, 208); CGContextScaleCTM(context, 1, -1);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationNone;
    CGContextSetShouldAntialias(context, false);
    draw();
    [NSGraphicsContext restoreGraphicsState];
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(192,208)];
    [image addRepresentation:rep]; return image;
}
static void Image(NSImage *image) {
    [image drawInRect:NSMakeRect(0,0,192,208) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}
static NSImage *Piece(NSImage *frame, NSBezierPath *mask) {
    return Raster(^{ [mask addClip]; Image(frame); });
}
static void Rotate(NSPoint pivot, double degrees) {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(context,pivot.x,pivot.y);
    CGContextRotateCTM(context,degrees * M_PI / 180);
    CGContextTranslateCTM(context,-pivot.x,-pivot.y);
}
static void RotatedImage(NSImage *image, NSPoint pivot, double degrees) {
    [NSGraphicsContext saveGraphicsState];
    Rotate(pivot,degrees);
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationLow;
    Image(image);
    [NSGraphicsContext restoreGraphicsState];
}

@implementation ShiroRig
- (BOOL)exportLayersToDirectory:(NSString *)directory error:(NSError **)error {
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSMutableDictionary *manifest = [NSMutableDictionary dictionary];
    for (NSNumber *key in @[@0,@3,@5,@7,@8]) {
        RigPose *pose = self.poses[key];
        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        for (NSString *name in @[@"body",@"tail",@"arm",@"feet",@"bug",@"joints"]) {
            NSImage *image = [pose valueForKey:name];
            if (!image) continue;
            NSString *filename = [NSString stringWithFormat:@"%@-%@.png",key,name];
            NSBitmapImageRep *rep = (NSBitmapImageRep *)image.representations.firstObject;
            NSData *data = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (![data writeToFile:[directory stringByAppendingPathComponent:filename] options:NSDataWritingAtomic error:error]) return NO;
            entry[name] = filename;
        }
        entry[@"tailPivot"] = @[@(pose.tailPivot.x),@(pose.tailPivot.y)];
        entry[@"armPivot"] = @[@(pose.armPivot.x),@(pose.armPivot.y)];
        manifest[key.stringValue] = entry;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:error];
    return data && [data writeToFile:[directory stringByAppendingPathComponent:@"rig.json"] options:NSDataWritingAtomic error:error];
}
- (instancetype)initWithAtlas:(NSImage *)atlas {
    if (!(self = [super init])) return nil;
    NSMutableDictionary *poses = [NSMutableDictionary dictionary];
    for (NSNumber *key in @[@0,@3,@5,@7,@8]) {
        NSInteger row = key.integerValue, col = row == 5 ? 4 : 0;
        double offset = row == 5 ? 5 : (row == 3 ? 1 : 0);
        NSImage *frame = Raster(^{
            [atlas drawInRect:NSMakeRect(0,offset,192,208)
                    fromRect:NSMakeRect(col * 192,2288-(row+1)*208,192,208)
                   operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        });
        RigPose *pose = [[RigPose alloc] init];
        NSBezierPath *tail;
        if (row == 5) tail = RigPolygon(@[@[@130,@147],@[@143,@140],@[@157,@145],@[@165,@157],@[@163,@173],@[@153,@181],@[@137,@181],@[@132,@173],@[@136,@161],@[@126,@156]],offset);
        else if (row == 7) tail = RigPolygon(@[@[@130,@147],@[@142,@141],@[@160,@147],@[@167,@159],@[@166,@177],@[@153,@190],@[@140,@190],@[@135,@181],@[@139,@166],@[@126,@158]],offset);
        else tail = RigPolygon(@[@[@129,@145],@[@145,@140],@[@163,@149],@[@171,@165],@[@168,@184],@[@153,@193],@[@139,@190],@[@136,@182],@[@141,@166],@[@127,@158]],offset);
        pose.tailPivot = NSMakePoint(131,155+offset);
        NSBezierPath *arm = nil;
        if (row == 7) {
            arm = RigPolygon(@[@[@44,@116],@[@57,@114],@[@78,@121],@[@79,@132],@[@71,@143],@[@58,@148],@[@46,@143],@[@41,@135],@[@42,@123]],offset);
            pose.armPivot = NSMakePoint(76,126+offset);
        } else if (row == 3) {
            arm = RigPolygon(@[@[@49,@113],@[@51,@108],@[@54,@109],@[@53,@106],@[@55,@103],@[@59,@107],@[@60,@105],@[@63,@107],@[@65,@106],@[@68,@109],@[@68,@111],@[@72,@109],@[@75,@113],@[@71,@119],@[@72,@125],@[@84,@128],@[@85,@137],@[@77,@145],@[@64,@144],@[@59,@140],@[@60,@130],@[@55,@125],@[@53,@122],@[@49,@119]],offset);
            pose.armPivot = NSMakePoint(82,133+offset);
        } else if (row == 5) {
            arm = RigPolygon(@[@[@54,@95],@[@63,@94],@[@67,@101],@[@76,@99],@[@90,@111],@[@86,@120],@[@81,@128],@[@66,@127],@[@57,@121],@[@53,@112]],offset);
            pose.armPivot = NSMakePoint(85,117+offset);
        }
        NSBezierPath *bug = row == 5 ? [NSBezierPath bezierPathWithRect:NSMakeRect(34,177+offset,27,23)] : nil;
        NSBezierPath *feet = row == 5 ? [NSBezierPath bezierPathWithRect:NSMakeRect(61,183,95,25)] : nil;
        pose.tail = Piece(frame,tail);
        if (arm) pose.arm = Piece(frame,arm);
        if (bug) pose.bug = Piece(frame,bug);
        if (feet) pose.feet = Piece(frame,feet);
        NSBezierPath *joints = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(pose.tailPivot.x-6,pose.tailPivot.y-6,12,12)];
        if (arm) [joints appendBezierPathWithOvalInRect:NSMakeRect(pose.armPivot.x-6,pose.armPivot.y-6,12,12)];
        pose.joints = Piece(frame,joints);
        pose.body = Raster(^{
            NSMutableArray *masks = [NSMutableArray arrayWithObject:tail];
            if (arm) [masks addObject:arm]; if (bug) [masks addObject:bug]; if (feet) [masks addObject:feet];
            for (NSBezierPath *mask in masks) {
                NSBezierPath *keep = [NSBezierPath bezierPathWithRect:NSMakeRect(0,0,192,208)];
                [keep appendBezierPath:mask]; keep.windingRule = NSWindingRuleEvenOdd; [keep addClip];
            }
            Image(frame);
        });
        if (row == 8) pose.lenses = RigPolygon(@[@[@62,@85],@[@115,@69],@[@120,@81],@[@72,@101]],0);
        poses[key] = pose;
    }
    self.poses = poses;
    return self;
}
+ (NSDictionary *)tracksForRow:(NSInteger)row time:(double)time {
    double t = fmax(0,time), tail = 0, arm = 0, lean = 0, bug = 0;
    if (row == 0) tail = 7 * sin(t * 2 * M_PI / 4.8);
    if (row == 7) { tail = 9 * sin(t * 2 * M_PI / 3.6); arm = 9 * sin(t * 2 * M_PI / 2.4); }
    if (row == 3) { tail = 7 * sin(t * 2 * M_PI / 3); arm = 12 * sin(t * 2 * M_PI / 0.9); }
    if (row == 8) tail = 6 * sin(t * 2 * M_PI / 3.2);
    if (row == 5) {
        double cycle = t * 2 * M_PI / 3.6;
        double alarm = (1-cos(cycle)) / 2;
        lean = 3 * alarm;
        arm = 12 * alarm;
        tail = -10 * sin(cycle);
        bug = 7 * alarm;
    }
    return @{@"tail":@(tail),@"arm":@(arm),@"lean":@(lean),@"bug":@(bug),@"scale":@1,@"feetY":@201};
}
- (void)drawRow:(NSInteger)row time:(double)time inRect:(NSRect)rect {
    RigPose *pose = self.poses[@(row)] ?: self.poses[@0];
    NSDictionary *tracks = [ShiroRig tracksForRow:row time:time];
    [NSGraphicsContext saveGraphicsState];
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(context,rect.origin.x,rect.origin.y);
    CGContextScaleCTM(context,rect.size.width/192,rect.size.height/208);
    if (pose.bug) {
        [NSGraphicsContext saveGraphicsState];
        CGContextTranslateCTM(context,[tracks[@"bug"] doubleValue],0);
        NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationLow;
        Image(pose.bug); [NSGraphicsContext restoreGraphicsState];
    }
    if (pose.feet) Image(pose.feet);
    [NSGraphicsContext saveGraphicsState];
    Rotate(NSMakePoint(97,184),[tracks[@"lean"] doubleValue]);
    // Only tails/arms move; independent drawings are never swapped in a loop.
    Image(pose.joints);
    RotatedImage(pose.tail,pose.tailPivot,[tracks[@"tail"] doubleValue]);
    if (pose.arm) RotatedImage(pose.arm,pose.armPivot,[tracks[@"arm"] doubleValue]);
    NSGraphicsContext.currentContext.imageInterpolation = row == 5 ? NSImageInterpolationLow : NSImageInterpolationNone;
    Image(pose.body);
    if (pose.lenses) {
        [NSGraphicsContext saveGraphicsState];
        [pose.lenses addClip];
        double x = fmod(fmax(0,time),3.2) / 3.2 * 160;
        [[NSColor colorWithCalibratedWhite:1 alpha:0.28] setFill];
        NSBezierPath *shine = RigPolygon(@[@[@(x),@65],@[@(x+3),@65],@[@(x-16),@109],@[@(x-19),@109]],0);
        [shine fill]; [NSGraphicsContext restoreGraphicsState];
    }
    [NSGraphicsContext restoreGraphicsState];
    [NSGraphicsContext restoreGraphicsState];
}
@end
