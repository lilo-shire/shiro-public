#import "ShiroRig.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) { fprintf(stderr,"Usage: rig-export animations-directory output-directory\n"); return 2; }
        ShiroRig *rig = [[ShiroRig alloc] initWithDirectory:@(argv[1])];
        if (!rig) return 3;
        [NSFileManager.defaultManager createDirectoryAtPath:@(argv[2]) withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSNumber *key in @[@0,@3,@5,@7,@8]) for (NSInteger frame = 0; frame < [rig frameCountForRow:key.integerValue]; frame++) {
            @autoreleasepool {
                NSImage *image = [NSImage imageWithSize:NSMakeSize(192,208) flipped:YES drawingHandler:^BOOL(NSRect rect) {
                    [rig drawRow:key.integerValue time:frame/[rig framesPerSecondForRow:key.integerValue] inRect:rect]; return YES;
                }];
                NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                NSString *path = [NSString stringWithFormat:@"%@/row-%@-%03ld.png",@(argv[2]),key,(long)frame];
                if (![[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES]) return 4;
            }
        }
        puts("PASS: exported supplied animation frames");
    }
    return 0;
}
