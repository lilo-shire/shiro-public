#import "ShiroRig.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) { fprintf(stderr,"Usage: rig-export atlas.png output-directory\n"); return 2; }
        NSImage *atlas = [[NSImage alloc] initWithContentsOfFile:@(argv[1])];
        if (!atlas) { fprintf(stderr,"Cannot read atlas\n"); return 1; }
        // NSImage honours PNG DPI metadata; the atlas grid is in pixel units.
        atlas.size = NSMakeSize(1536,2288);
        ShiroRig *rig = [[ShiroRig alloc] initWithAtlas:atlas];
        NSError *error = nil;
        if (![rig exportLayersToDirectory:@(argv[2]) error:&error]) { fprintf(stderr,"%s\n",error.description.UTF8String); return 1; }
        puts("PASS: exported native animation layers for Windows");
    }
    return 0;
}
