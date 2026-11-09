#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <UserNotifications/UserNotifications.h>
#import <AVFoundation/AVFoundation.h>
#import "TimerModel.h"
#import "TaskModel.h"
#import "LinkedFile.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <sys/stat.h>
#import "MixUI.h"
#import "ShiroRig.h"
#include <math.h>

@class ShiroApp;
@interface PetView : NSView
@property(nonatomic, weak) ShiroApp *owner;
@property(nonatomic, strong) ShiroRig *rig;
@property(nonatomic) NSInteger row;
@property(nonatomic) NSPoint dragStart;
@property(nonatomic) NSPoint windowStart;
@property(nonatomic) BOOL dragged;
@property(nonatomic) double manualTime;
@end

@interface ShiroPanelWindow : NSPanel @end
@implementation ShiroPanelWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (void)cancelOperation:(id)sender { [self orderOut:nil]; }
// Shiro has no visible menu bar, so ⌘V and friends are routed here by physical key (works with any keyboard layout).
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if (event.type == NSEventTypeKeyDown && (flags & NSEventModifierFlagCommand) && !(flags & (NSEventModifierFlagControl | NSEventModifierFlagOption))) {
        BOOL shift = (flags & NSEventModifierFlagShift) != 0;
        SEL action = NULL;
        switch (event.keyCode) {
            case 9: action = @selector(paste:); break;        // V
            case 8: action = @selector(copy:); break;         // C
            case 7: action = @selector(cut:); break;          // X
            case 0: action = @selector(selectAll:); break;    // A
            case 6: action = shift ? @selector(redo:) : @selector(undo:); break;   // Z
        }
        if (action && [self.firstResponder tryToPerform:action with:self]) return YES;
    }
    return [super performKeyEquivalent:event];
}
@end

@interface ShiroPasteProbe : NSView
@property(nonatomic) NSInteger pasted;
@end
@implementation ShiroPasteProbe
- (BOOL)acceptsFirstResponder { return YES; }
- (void)paste:(id)sender { self.pasted++; }
@end

@interface ShiroApp : NSObject <NSApplicationDelegate, ShiroPanelDelegate, ShiroSettingsDelegate, UNUserNotificationCenterDelegate>
@property(nonatomic, strong) ShiroTimer *timer;
@property(nonatomic, strong) ShiroTaskStore *taskStore;
@property(nonatomic, strong) NSWindow *petWindow;
@property(nonatomic, strong) PetView *pet;
@property(nonatomic, strong) ShiroPanelWindow *panel;
@property(nonatomic, strong) ShiroPanelView *panelView;
@property(nonatomic, strong) NSPopover *settingsPopover;
@property(nonatomic, strong) ShiroSettingsController *settingsController;
@property(nonatomic, strong) NSStatusItem *status;
@property(nonatomic, strong) NSTimer *clock;
@property(nonatomic, strong) NSTimer *animation;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSSound *> *sounds;
@property(nonatomic) NSTimeInterval reactionUntil;
@property(nonatomic) NSInteger reactionRow;
@property(nonatomic) double motionStartedAt;
@property(nonatomic) double globalWorkRemaining;
@property(nonatomic, copy) NSString *themeID, *language, *scope, *soundPack;
@property(nonatomic) double volume;
@property(nonatomic) BOOL notify;
@property(nonatomic, copy) NSString *renderPath;
@property(nonatomic, copy) NSString *lastBadge;
@property(nonatomic, copy) NSString *linkedPath, *linkedSignature;
@property(nonatomic, strong) NSArray<ShiroFileTask *> *fileTasks;
@property(nonatomic) BOOL fileMissing, fileCollapsed;
@property(nonatomic) NSInteger fileIndex;
// A task from the connected file can be the current one instead of a Shiro task; it is remembered by its text.
@property(nonatomic, copy) NSString *activeFileTitle;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *fileRemaining;
// Shiro's own order of the file block (by task text); the file itself is never reordered.
@property(nonatomic, strong) NSArray<NSString *> *fileOrder;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *fileGroups;
@property(nonatomic) NSTimeInterval animationInterval;
@property(nonatomic, strong) AVAudioPlayer *ambientPlayer;
@property(nonatomic) NSTimeInterval ambientPreviewUntil;
@property(nonatomic) CFTimeInterval marqueeStartedAt;
@property(nonatomic, copy) NSString *marqueeTitle;
- (NSString *)activeTaskTitle;
- (BOOL)marqueeNeeded;
- (CGFloat)marqueeShiftForWidth:(CGFloat)width;
@property(nonatomic) NSTimeInterval lastFileCheck;
- (void)save;
- (NSMenu *)menu;
- (void)togglePanel:(id)sender;
- (NSString *)badgeTime;
- (ShiroTheme *)theme;
@end

static NSTimeInterval Now(void) { return NSDate.date.timeIntervalSince1970; }

// An outlined heart for the menu bar; a template image follows the light or dark menu bar.
static NSImage *ShiroMenuBarIcon(void) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 16) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        NSBezierPath *heart = [NSBezierPath bezierPath];
        [heart moveToPoint:NSMakePoint(9, 2.2)];
        [heart curveToPoint:NSMakePoint(2.2, 9.6) controlPoint1:NSMakePoint(6.4, 4.3) controlPoint2:NSMakePoint(2.2, 6.6)];
        [heart curveToPoint:NSMakePoint(5.6, 13.6) controlPoint1:NSMakePoint(2.2, 12) controlPoint2:NSMakePoint(3.8, 13.6)];
        [heart curveToPoint:NSMakePoint(9, 11.4) controlPoint1:NSMakePoint(7.2, 13.6) controlPoint2:NSMakePoint(8.4, 12.6)];
        [heart curveToPoint:NSMakePoint(12.4, 13.6) controlPoint1:NSMakePoint(9.6, 12.6) controlPoint2:NSMakePoint(10.8, 13.6)];
        [heart curveToPoint:NSMakePoint(15.8, 9.6) controlPoint1:NSMakePoint(14.2, 13.6) controlPoint2:NSMakePoint(15.8, 12)];
        [heart curveToPoint:NSMakePoint(9, 2.2) controlPoint1:NSMakePoint(15.8, 6.6) controlPoint2:NSMakePoint(11.6, 4.3)];
        [heart closePath];
        heart.lineWidth = 1.5; heart.lineJoinStyle = NSLineJoinStyleRound;
        [NSColor.blackColor setStroke]; [heart stroke];
        return YES;
    }];
    image.template = YES;
    return image;
}

#pragma mark - Pet

@implementation PetView
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) _manualTime = -1;
    return self;
}
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
    CGContextClearRect(NSGraphicsContext.currentContext.CGContext, dirty);
    NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationNone;
    double elapsed = self.manualTime >= 0 ? self.manualTime : fmax(0, CACurrentMediaTime() - self.owner.motionStartedAt);
    if (NSIntersectsRect(dirty, NSMakeRect(0, 0, 192, 156))) [self.rig drawRow:self.row time:elapsed inRect:NSMakeRect(24, 0, 144, 156)];
    if (!NSIntersectsRect(dirty, NSMakeRect(0, 150, 192, 62)) || !self.owner.timer) return;
    // The badge uses the head colours of the chosen scheme, so it matches the top of the window.
    // With a current task it grows to two lines; a long title runs as a ticker.
    ShiroTheme *theme = self.owner.theme;
    NSString *title = self.owner.activeTaskTitle;
    BOOL twoLines = title.length > 0;
    NSRect badge = twoLines ? NSMakeRect(10, 158, 172, 50) : NSMakeRect(22, 170, 148, 36);
    CGFloat radius = twoLines ? 16 : 18;
    NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:badge xRadius:radius yRadius:radius];
    [theme.headBackground setFill]; [pill fill];
    pill.lineWidth = 1; [[theme.headInk colorWithAlphaComponent:.12] setStroke]; [pill stroke];
    CGFloat lineMid = twoLines ? NSMinY(badge) + 17 : NSMidY(badge);
    NSDictionary *timeStyle = @{NSFontAttributeName:ShiroDisplayFont(16, 400), NSForegroundColorAttributeName:theme.headInk};
    NSString *time = self.owner.badgeTime;
    NSSize size = [time sizeWithAttributes:timeStyle];
    [time drawAtPoint:NSMakePoint(NSMinX(badge) + 14, round(lineMid - size.height / 2)) withAttributes:timeStyle];
    NSString *phase = ShiroL([self.owner.timer.phase isEqual:@"break"] ? @"break" : @"focus");
    NSDictionary *phaseStyle = @{NSFontAttributeName:ShiroTextFont(11, 600), NSForegroundColorAttributeName:theme.headMuted};
    NSSize phaseSize = [phase sizeWithAttributes:phaseStyle];
    [phase drawAtPoint:NSMakePoint(NSMaxX(badge) - 14 - phaseSize.width, round(lineMid - phaseSize.height / 2)) withAttributes:phaseStyle];
    if (!twoLines) return;
    NSDictionary *titleStyle = @{NSFontAttributeName:ShiroTextFont(12, 500), NSForegroundColorAttributeName:[theme.headInk colorWithAlphaComponent:.85]};
    NSRect lane = NSMakeRect(NSMinX(badge) + 14, NSMinY(badge) + 28, badge.size.width - 28, 16);
    CGFloat width = [title sizeWithAttributes:titleStyle].width;
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(lane);
    if (self.owner.marqueeNeeded) {
        // One pass: the title slides left until its second copy reaches the start, then the static start shows again.
        CGFloat shift = self.manualTime >= 0 ? fmin(self.manualTime * 34, width + 36) : [self.owner marqueeShiftForWidth:width];
        [title drawAtPoint:NSMakePoint(NSMinX(lane) - shift, NSMinY(lane)) withAttributes:titleStyle];
        [title drawAtPoint:NSMakePoint(NSMinX(lane) - shift + width + 36, NSMinY(lane)) withAttributes:titleStyle];
    } else {
        NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
        para.lineBreakMode = NSLineBreakByTruncatingTail;
        NSMutableDictionary *style = [titleStyle mutableCopy]; style[NSParagraphStyleAttributeName] = para;
        [title drawInRect:lane withAttributes:style];
    }
    [NSGraphicsContext restoreGraphicsState];
}
- (void)mouseDown:(NSEvent *)event {
    self.dragStart = NSEvent.mouseLocation;
    self.windowStart = self.window.frame.origin;
    self.dragged = NO;
}
- (void)mouseDragged:(NSEvent *)event {
    NSPoint cursor = NSEvent.mouseLocation;
    CGFloat dx = cursor.x - self.dragStart.x, dy = cursor.y - self.dragStart.y;
    if (hypot(dx, dy) > 4) self.dragged = YES;
    if (self.dragged) [self.window setFrameOrigin:NSMakePoint(self.windowStart.x + dx, self.windowStart.y + dy)];
}
- (void)mouseUp:(NSEvent *)event {
    if (self.dragged) {
        NSScreen *screen = self.window.screen ?: NSScreen.mainScreen;
        NSRect area = screen.visibleFrame, frame = self.window.frame;
        frame.origin.x = fmax(NSMinX(area), fmin(frame.origin.x, NSMaxX(area) - frame.size.width));
        frame.origin.y = fmax(NSMinY(area), fmin(frame.origin.y, NSMaxY(area) - frame.size.height));
        [self.window setFrameOrigin:frame.origin];
        [self.owner save];
    } else [self.owner togglePanel:self];
}
- (void)rightMouseDown:(NSEvent *)event { [NSMenu popUpContextMenu:self.owner.menu withEvent:event forView:self]; }
- (BOOL)isAccessibilityElement { return YES; }
- (NSAccessibilityRole)accessibilityRole { return NSAccessibilityButtonRole; }
- (NSString *)accessibilityLabel {
    NSString *title = self.owner.activeTaskTitle;
    return title.length ? [NSString stringWithFormat:@"Shiro %@, %@", self.owner.badgeTime, title] : [NSString stringWithFormat:@"Shiro %@", self.owner.badgeTime];
}
- (BOOL)accessibilityPerformPress { [self.owner togglePanel:self]; return YES; }
@end

#pragma mark - App

@implementation ShiroApp
@synthesize themeID = _themeID, language = _language, scope = _scope, soundPack = _soundPack, volume = _volume, notify = _notify, uiScale = _uiScale, ambient = _ambient, ambientVolume = _ambientVolume;

- (ShiroTheme *)theme { return [ShiroTheme themeWithIdentifier:self.themeID]; }
- (BOOL)live { return !self.renderPath; }

- (void)loadSettings {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *systemLanguage = [NSLocale.preferredLanguages.firstObject hasPrefix:@"ru"] ? @"ru" : @"en";
    self.language = [d stringForKey:@"language"] ?: systemLanguage;
    ShiroSetLanguage(self.language);
    self.themeID = [ShiroTheme themeWithIdentifier:[d stringForKey:@"theme"]].identifier;
    self.scope = [[d stringForKey:@"timerScope"] isEqual:@"task"] ? @"task" : @"global";
    self.soundPack = [@[@"glass", @"wood", @"air"] containsObject:[d stringForKey:@"soundPack"]] ? [d stringForKey:@"soundPack"] : @"glass";
    // Version 0.5 stored only an on/off switch for sound.
    if ([d objectForKey:@"volume"]) self.volume = fmin(1, fmax(0, [d doubleForKey:@"volume"]));
    else self.volume = [d objectForKey:@"sound"] && ![d boolForKey:@"sound"] ? 0 : .8;
    self.notify = [d objectForKey:@"notify"] ? [d boolForKey:@"notify"] : YES;
    self.ambient = [d boolForKey:@"ambient"];
    self.ambientVolume = [d objectForKey:@"ambientVolume"] ? fmin(1, fmax(0, [d doubleForKey:@"ambientVolume"])) : .35;
    self.uiScale = [d objectForKey:@"uiScale"] ? fmin(1.5, fmax(.5, [d doubleForKey:@"uiScale"])) : ShiroScaleSteps().firstObject.doubleValue;
    self.globalWorkRemaining = [d objectForKey:@"globalWorkRemaining"] ? [d doubleForKey:@"globalWorkRemaining"] : -1;
    self.linkedPath = [d stringForKey:@"linkedFile"];
    self.fileCollapsed = [d boolForKey:@"linkedFileCollapsed"];
    self.fileIndex = [d objectForKey:@"linkedFileIndex"] ? [d integerForKey:@"linkedFileIndex"] : NSIntegerMax;
    self.activeFileTitle = [d stringForKey:@"activeFileTask"];
    self.fileRemaining = [[d dictionaryForKey:@"fileTaskRemaining"] mutableCopy] ?: [NSMutableDictionary dictionary];
    self.fileOrder = [d arrayForKey:@"fileTaskOrder"] ?: @[];
    self.fileGroups = [[d dictionaryForKey:@"fileTaskGroups"] mutableCopy] ?: [NSMutableDictionary dictionary];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    ShiroRegisterFonts();
    [self loadSettings];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.timer = [[ShiroTimer alloc] initWithState:[defaults dictionaryForKey:@"timer"] now:Now()];
    self.taskStore = [[ShiroTaskStore alloc] initWithState:[defaults dictionaryForKey:@"checklist"] defaultSections:@[ShiroL(@"defaultWork"), ShiroL(@"defaultPersonal")]];
    if (self.timer.running && [self.timer.phase isEqual:@"work"] && [self creditsTasks] && self.taskStore.focusAnchorRemaining < 0)
        [self.taskStore beginFocusAtRemaining:[self.timer remainingAt:Now()]];

    self.petWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 192, 212) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.petWindow.opaque = NO; self.petWindow.backgroundColor = NSColor.clearColor; self.petWindow.hasShadow = NO;
    // One level above the window so Shiro is never hidden behind it.
    self.petWindow.level = NSFloatingWindowLevel + 1;
    self.petWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.petWindow.releasedWhenClosed = NO;
    self.pet = [[PetView alloc] initWithFrame:NSMakeRect(0, 0, 192, 212)];
    self.pet.owner = self;
    self.pet.rig = [[ShiroRig alloc] initWithDirectory:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"animations"]];
    if (!self.pet.rig) { NSLog(@"Cannot load Shiro animations"); [NSApp terminate:nil]; return; }
    self.petWindow.contentView = self.pet;
    NSRect area = NSScreen.mainScreen.visibleFrame;
    CGFloat x = [defaults objectForKey:@"petX"] ? [defaults doubleForKey:@"petX"] : NSMaxX(area) - 218;
    CGFloat y = [defaults objectForKey:@"petY"] ? [defaults doubleForKey:@"petY"] : NSMinY(area) + 28;
    x = fmax(NSMinX(area), fmin(x, NSMaxX(area) - 192));
    y = fmax(NSMinY(area), fmin(y, NSMaxY(area) - 212));
    [self.petWindow setFrameOrigin:NSMakePoint(x, y)];
    [self.petWindow orderFrontRegardless];

    [self reloadLinkedFile];
    [self makePanel];
    [self installEditMenu];
    self.status = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.status.button.image = ShiroMenuBarIcon();
    self.status.button.imagePosition = NSImageLeft;
    self.status.button.accessibilityLabel = @"Широ";
    self.status.menu = self.menu;
    if (self.notify) [self requestNotifications];
    self.clock = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.clock forMode:NSRunLoopCommonModes];
    [self tick:nil];
    [self chooseAnimation];
}

#pragma mark Panel

// An invisible main menu with the standard Edit commands, so text fields get the usual shortcuts.
- (void)installEditMenu {
    NSMenu *main = [[NSMenu alloc] init];
    NSMenuItem *appItem = [[NSMenuItem alloc] init]; NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:ShiroL(@"menuQuit") action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu; [main addItem:appItem];
    NSMenuItem *editItem = [[NSMenuItem alloc] init]; NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [edit addItem:NSMenuItem.separatorItem];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = edit; [main addItem:editItem];
    NSApp.mainMenu = main;
}

- (void)makePanel {
    self.panel = [[ShiroPanelWindow alloc] initWithContentRect:NSMakeRect(0, 0, ShiroPanelWidth * self.uiScale, 600) styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.panel.floatingPanel = YES; self.panel.level = NSFloatingWindowLevel;
    self.panel.releasedWhenClosed = NO; self.panel.hidesOnDeactivate = NO;
    self.panel.opaque = NO; self.panel.backgroundColor = NSColor.clearColor; self.panel.hasShadow = YES;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.panelView = [self makePanelView];
    self.panel.contentView = self.panelView;
    [self panelContentHeightChanged];
}
- (ShiroPanelView *)makePanelView {
    ShiroPanelView *view = [[ShiroPanelView alloc] initWithFrame:NSMakeRect(0, 0, ShiroPanelWidth * self.uiScale, 600)];
    view.uiScale = self.uiScale;
    view.delegate = self; view.timer = self.timer; view.store = self.taskStore;
    view.theme = self.theme; view.scope = self.scope; view.now = Now();
    [self pushFileTo:view];
    return view;
}
- (CGFloat)maxPanelHeight {
    NSScreen *screen = self.petWindow.screen ?: NSScreen.mainScreen;
    return screen ? NSHeight(screen.visibleFrame) - 40 : 900;
}
- (void)panelContentHeightChanged {
    if (!self.panel) return;
    CGFloat height = round(fmin(self.panelView.preferredHeight, self.maxPanelHeight)), width = round(ShiroPanelWidth * self.uiScale);
    NSRect frame = self.panel.frame;
    if (fabs(frame.size.height - height) < 0.5 && fabs(frame.size.width - width) < 0.5) return;
    CGFloat top = NSMaxY(frame), right = NSMaxX(frame);
    frame.size.height = height; frame.origin.y = top - height;
    // A size change keeps the edge next to Shiro in place.
    frame.origin.x = right - width; frame.size.width = width;
    if (self.panel.visible) {
        NSRect area = (self.panel.screen ?: NSScreen.mainScreen).visibleFrame;
        if (NSMinY(frame) < NSMinY(area)) frame.origin.y = NSMinY(area);
    }
    [self.panel setFrame:frame display:YES];
    self.panelView.frame = NSMakeRect(0, 0, width, height);
    [self.panel invalidateShadow];
}
- (void)placePanel {
    // The window opens left of Shiro and a little higher than his feet, so he stands at its right edge.
    NSScreen *screen = self.petWindow.screen ?: NSScreen.mainScreen;
    NSRect area = screen.visibleFrame, pet = self.petWindow.frame, frame = self.panel.frame;
    // Shiro's figure fills x 24…168 and the top 156 points of the 192×212 pet window.
    CGFloat left = NSMinX(pet) + 30 - frame.size.width, right = NSMinX(pet) + 162;
    CGFloat x = left >= NSMinX(area) ? left : (right + frame.size.width <= NSMaxX(area) ? right : NSMinX(area));
    CGFloat y = NSMinY(pet) + 64;
    x = fmax(NSMinX(area), fmin(x, NSMaxX(area) - frame.size.width));
    y = fmax(NSMinY(area), fmin(y, NSMaxY(area) - frame.size.height));
    [self.panel setFrameOrigin:NSMakePoint(x, y)];
}
- (void)togglePanel:(id)sender {
    [self playMarquee];
    if (self.panel.visible) { [self.settingsPopover close]; [self.panel orderOut:nil]; return; }
    [self panelContentHeightChanged];
    [self placePanel];
    [NSApp activateIgnoringOtherApps:YES];
    [self.panel makeKeyAndOrderFront:nil];
    [self.petWindow orderFrontRegardless];
}
- (void)pushFileTo:(ShiroPanelView *)view {
    view.fileName = self.linkedPath ? self.linkedPath.lastPathComponent.stringByDeletingPathExtension : nil;
    view.fileTasks = self.fileTasks ?: @[]; view.fileMissing = self.fileMissing; view.fileCollapsed = self.fileCollapsed;
    view.fileIndex = self.fileIndex;
    view.activeFileTitle = self.activeFileTitle;
}
- (NSString *)activeTaskTitle { return self.activeFileTitle ?: [self.taskStore taskWithID:self.taskStore.activeTaskID][@"title"]; }
- (BOOL)hasSelection { return self.activeFileTitle != nil || self.taskStore.activeTaskID != nil; }
// Only one current task at a time: choosing a file task clears the Shiro selection and the other way round.
- (void)keepFileSelection { if (self.activeFileTitle) { self.taskStore.activeTaskID = nil; self.taskStore.focusAnchorRemaining = -1; } }
- (void)refreshPanel { [self pushFileTo:self.panelView]; self.panelView.now = Now(); [self.panelView reloadContent]; [self.panelView refreshTimer]; self.status.menu = self.menu; }

#pragma mark Timer coordination

// Focus time counts towards a task only with a separate timer per task; a shared timer is not tied to one task.
- (BOOL)creditsTasks { return [self.scope isEqual:@"task"] && self.taskStore.activeTaskID != nil; }
- (void)creditCurrentFocus {
    if (self.timer.running && [self.timer.phase isEqual:@"work"] && [self creditsTasks])
        [self.taskStore creditThroughRemaining:[self.timer remainingAt:Now()] completedPomodoro:NO];
}
- (void)stashSelectedTaskTime {
    if (![self.scope isEqual:@"task"]) return;
    double value = [self.timer workRemainingAt:Now()];
    if (self.activeFileTitle) self.fileRemaining[self.activeFileTitle] = @(value);
    else if (self.taskStore.activeTaskID) [self.taskStore setRemaining:value forTaskID:self.taskStore.activeTaskID];
}
- (void)loadSelectedTaskTime {
    if (![self.scope isEqual:@"task"]) return;
    double value = self.activeFileTitle ? (self.fileRemaining[self.activeFileTitle] ? self.fileRemaining[self.activeFileTitle].doubleValue : -1)
                 : self.taskStore.activeTaskID ? [self.taskStore remainingForTaskID:self.taskStore.activeTaskID] : -1;
    [self.timer loadWorkRemaining:value at:Now()];
}
- (void)stopFocusIfRunning {
    if (self.timer.running && [self.timer.phase isEqual:@"work"]) { [self creditCurrentFocus]; [self.timer pauseAt:Now()]; }
}
- (void)playReactionRow:(NSInteger)row {
    self.reactionRow = row;
    double duration = self.pet.rig ? [self.pet.rig durationForRow:row] : (row == 8 ? 6 : 4);
    self.reactionUntil = Now() + duration;
    if (self.pet.row == row) self.motionStartedAt = CACurrentMediaTime();
}

- (void)tick:(NSTimer *)timer {
    // The daily file is replaced every morning: check its path every two seconds and re-read on any change.
    if (self.linkedPath && Now() - self.lastFileCheck >= 2) {
        self.lastFileCheck = Now();
        if (![[self signatureOfLinkedFile] isEqual:self.linkedSignature ?: @""]) { [self reloadLinkedFile]; [self refreshPanel]; }
    }
    NSString *before = self.timer.phase;
    BOOL credits = [self creditsTasks];
    NSString *event = [self.timer tickAt:Now()];
    if ([event isEqual:@"workFinished"] && [before isEqual:@"work"] && self.activeFileTitle && [self.scope isEqual:@"task"]) [self.fileRemaining removeObjectForKey:self.activeFileTitle];
    if ([event isEqual:@"workFinished"] && [before isEqual:@"work"] && credits) {
        [self.taskStore creditThroughRemaining:0 completedPomodoro:YES];
        [self.taskStore setRemaining:-1 forTaskID:self.taskStore.activeTaskID];
    }
    if (event) [self intervalFinished:event];
    self.panelView.now = Now();
    if (event) [self refreshPanel]; else [self.panelView refreshTimer];
    NSString *title = self.activeTaskTitle ?: @"";
    if (![title isEqual:self.marqueeTitle ?: @""]) { BOOL first = self.marqueeTitle == nil; self.marqueeTitle = title; if (!first) [self playMarquee]; }
    NSString *badge = [NSString stringWithFormat:@"%@%@%d%@%d", self.badgeTime, self.timer.phase, self.timer.running, title, self.marqueeNeeded];
    if (![badge isEqual:self.lastBadge]) {
        self.lastBadge = badge;
        [self.pet setNeedsDisplayInRect:NSMakeRect(0, 150, 192, 62)];
        // Narrow on purpose: on Macs with a notch wide items get hidden. The time shows only while the timer runs.
        self.status.button.title = self.timer.running ? [@" " stringByAppendingString:self.badgeTime] : @"";
        self.status.button.toolTip = [NSString stringWithFormat:@"Широ %@", self.badgeTime];
    }
    [self chooseAnimation];
    [self updateAmbient];
}
- (NSString *)badgeTime {
    NSInteger s = (NSInteger)ceil(fmax(0, [self.timer remainingAt:Now()]) - 0.0001);
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(s / 60), (long)(s % 60)];
}
- (void)intervalFinished:(NSString *)event {
    BOOL focus = [event isEqual:@"workFinished"];
    if (focus) [self playReactionRow:8]; else [self playReactionRow:3];
    [self playSound:focus ? @"focus-end" : @"break-end" gain:1];
    [self postNotificationTitle:ShiroL(focus ? @"focusDone" : @"breakDone") body:ShiroL(focus ? @"focusDoneBody" : @"breakDoneBody")];
    [self playMarquee];
    [self save];
}
- (NSInteger)desiredRow {
    if (Now() < self.reactionUntil) return self.reactionRow;
    if (!self.timer.running) return 0;
    return [self.timer.phase isEqual:@"break"] ? 0 : 7;
}
- (void)chooseAnimation {
    NSInteger row = [self desiredRow];
    double fps = self.pet.rig ? [self.pet.rig framesPerSecondForRow:row] : 25;
    NSTimeInterval interval = 1.0 / (self.marqueeNeeded ? fmax(30, fps) : fps);
    if (self.animation && self.pet.row == row && interval == self.animationInterval) return;
    BOOL sameRow = self.animation && self.pet.row == row;
    [self.animation invalidate]; self.animation = nil;
    // Only a new row restarts the motion; a frame-rate change for the ticker keeps it running smoothly.
    if (!sameRow) { self.pet.row = row; self.pet.needsDisplay = YES; self.motionStartedAt = CACurrentMediaTime(); }
    self.animationInterval = interval;
    self.animation = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(animate:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.animation forMode:NSRunLoopCommonModes];
}
- (void)animate:(NSTimer *)timer {
    if (self.pet.row != [self desiredRow]) [self chooseAnimation];
    [self.pet setNeedsDisplayInRect:NSMakeRect(0, 0, 192, 156)];
    if (self.marqueeNeeded) [self.pet setNeedsDisplayInRect:NSMakeRect(0, 150, 192, 62)];
}
// The badge shows the start of the title. After an action (window, timer, task change) a long title runs once and comes back to its start.
static const CGFloat kMarqueeGap = 36, kMarqueeSpeed = 34, kMarqueePause = 0.6;
- (CGFloat)titleWidth { return [self.activeTaskTitle sizeWithAttributes:@{NSFontAttributeName:ShiroTextFont(12, 500)}].width; }
- (void)playMarquee { self.marqueeStartedAt = CACurrentMediaTime(); [self chooseAnimation]; [self.pet setNeedsDisplayInRect:NSMakeRect(0, 150, 192, 62)]; }
- (BOOL)marqueeNeeded {
    NSString *title = self.activeTaskTitle;
    if (!title.length || self.marqueeStartedAt <= 0 || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return NO;
    CGFloat width = self.titleWidth;
    if (width <= 172 - 28) return NO;
    return CACurrentMediaTime() - self.marqueeStartedAt < kMarqueePause + (width + kMarqueeGap) / kMarqueeSpeed;
}
- (CGFloat)marqueeShiftForWidth:(CGFloat)width {
    CGFloat t = CACurrentMediaTime() - self.marqueeStartedAt;
    return t < kMarqueePause ? 0 : fmin((t - kMarqueePause) * kMarqueeSpeed, width + kMarqueeGap);
}

#pragma mark Panel actions

- (void)panelToggleTimer {
    if (self.timer.running) {
        [self creditCurrentFocus];
        [self.timer pauseAt:Now()];
        self.reactionUntil = 0;
    } else {
        BOOL focus = [self.timer.phase isEqual:@"work"];
        if (focus && [self.scope isEqual:@"task"] && !self.hasSelection) { [self.panelView showToast:ShiroL(@"pickTask")]; return; }
        [self.timer startAt:Now()];
        if (focus && [self creditsTasks]) [self.taskStore beginFocusAtRemaining:[self.timer remainingAt:Now()]];
        // A break opens with the one-off cockroach scare, then calm rest.
        if (focus) self.reactionUntil = 0; else [self playReactionRow:5];
        [self playSound:@"start" gain:.45];
    }
    [self playMarquee];
    [self save]; [self tick:nil];
}
- (void)panelResetTimer {
    [self creditCurrentFocus];
    [self.timer reset];
    self.taskStore.focusAnchorRemaining = -1;
    if ([self.timer.phase isEqual:@"work"]) [self stashSelectedTaskTime];
    self.reactionUntil = 0;
    [self playMarquee];
    [self save]; [self tick:nil];
}
- (void)panelSwitchToPhase:(NSString *)phase {
    if ([phase isEqual:self.timer.phase]) return;
    [self creditCurrentFocus];
    [self.timer switchToPhase:phase at:Now()];
    self.taskStore.focusAnchorRemaining = -1;
    self.reactionUntil = 0;
    [self playMarquee];
    [self save]; [self tick:nil];
}
- (void)panelSelectTask:(NSString *)taskID {
    if ([self.taskStore.activeTaskID isEqual:taskID] && !self.activeFileTitle) return;
    BOOL separate = [self.scope isEqual:@"task"];
    if (separate) { [self creditCurrentFocus]; [self stashSelectedTaskTime]; }
    self.activeFileTitle = nil;
    if ([self.taskStore.activeTaskID isEqual:taskID]) self.taskStore.activeTaskID = nil;
    if (![self.taskStore selectTaskID:taskID]) return;
    if (separate) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelToggleTask:(NSString *)taskID {
    BOOL selected = [self.taskStore.activeTaskID isEqual:taskID];
    if (selected) { [self stopFocusIfRunning]; [self stashSelectedTaskTime]; }
    NSString *before = self.taskStore.activeTaskID;
    BOOL done = [self.taskStore toggleTaskID:taskID];
    if (done) { [self playReactionRow:3]; [self playSound:@"task-done" gain:.8]; }
    [self keepFileSelection];
    if (![before isEqual:self.taskStore.activeTaskID]) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelAddTask:(NSString *)title toSection:(NSString *)sectionID {
    NSString *before = self.taskStore.activeTaskID;
    if (![self.taskStore addTitle:title toSectionID:sectionID]) return;
    [self keepFileSelection];
    if (!before && self.taskStore.activeTaskID) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (NSString *)panelAddSection:(NSString *)title {
    NSString *created = [self.taskStore addSectionTitle:title];
    [self afterTaskChange];
    return created;
}
- (void)panelRenameTask:(NSString *)taskID title:(NSString *)title { [self.taskStore renameTaskID:taskID title:title]; [self afterTaskChange]; }
- (void)panelRenameSection:(NSString *)sectionID title:(NSString *)title { [self.taskStore renameSectionID:sectionID title:title]; [self afterTaskChange]; }
- (void)panelDeleteTask:(NSString *)taskID {
    if ([self.taskStore.activeTaskID isEqual:taskID]) [self stopFocusIfRunning];
    NSString *before = self.taskStore.activeTaskID;
    [self.taskStore deleteTaskID:taskID];
    if (![before isEqual:self.taskStore.activeTaskID]) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelDeleteSection:(NSString *)sectionID {
    NSString *before = self.taskStore.activeTaskID;
    if ([[self.taskStore taskWithID:before][@"sectionID"] isEqual:sectionID]) [self stopFocusIfRunning];
    [self.taskStore deleteSectionID:sectionID];
    if (!(before == self.taskStore.activeTaskID || [before isEqual:self.taskStore.activeTaskID])) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelMoveTask:(NSString *)taskID toSection:(NSString *)sectionID before:(NSString *)beforeID {
    NSString *before = self.taskStore.activeTaskID;
    if (![self.taskStore moveTaskID:taskID toSectionID:sectionID beforeTaskID:beforeID]) return;
    [self.taskStore expandSectionID:sectionID];
    [self keepFileSelection];
    if (![before isEqual:self.taskStore.activeTaskID]) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelSetLink:(NSString *)link forTask:(NSString *)taskID { [self.taskStore setLink:link forTaskID:taskID]; [self afterTaskChange]; }
- (void)panelToggleDoneList { [self.taskStore toggleDoneCollapsed]; [self afterTaskChange]; }
- (void)panelClearDone { [self.taskStore clearDone]; [self afterTaskChange]; }
- (void)panelToggleSection:(NSString *)sectionID { [self.taskStore toggleSectionID:sectionID]; [self afterTaskChange]; }
- (void)panelExpandSection:(NSString *)sectionID { [self.taskStore expandSectionID:sectionID]; [self afterTaskChange]; }
- (void)panelMoveSection:(NSString *)sectionID toIndex:(NSInteger)index { [self.taskStore moveSectionID:sectionID toIndex:index]; [self afterTaskChange]; }
- (void)afterTaskChange { [self save]; [self refreshPanel]; [self tick:nil]; }
- (void)panelClose { [self.settingsPopover close]; [self.panel orderOut:nil]; [self playMarquee]; }
- (void)panelShowSettingsFromRect:(NSRect)rect {
    if (self.settingsPopover.shown) { [self.settingsPopover close]; return; }
    if (!self.settingsPopover) {
        self.settingsController = [[ShiroSettingsController alloc] init];
        self.settingsController.delegate = self;
        self.settingsPopover = [[NSPopover alloc] init];
        self.settingsPopover.behavior = NSPopoverBehaviorTransient;
        self.settingsPopover.contentViewController = self.settingsController;
    }
    [self.settingsController refresh];
    self.settingsPopover.appearance = [NSAppearance appearanceNamed:self.theme.dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    [self.settingsPopover showRelativeToRect:rect ofView:self.panelView preferredEdge:NSRectEdgeMaxY];
}

#pragma mark Settings

- (double)workMinutes { return self.timer.workSeconds / 60; }
- (double)breakMinutes { return self.timer.breakSeconds / 60; }
- (void)settingsChangedTheme:(NSString *)themeID {
    self.themeID = [ShiroTheme themeWithIdentifier:themeID].identifier;
    self.panelView.theme = self.theme;
    self.settingsPopover.appearance = [NSAppearance appearanceNamed:self.theme.dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
    self.lastBadge = nil; [self save]; [self refreshPanel]; [self tick:nil];
}
- (void)settingsChangedLanguage:(NSString *)language {
    self.language = [language isEqual:@"en"] ? @"en" : @"ru";
    ShiroSetLanguage(self.language);
    self.lastBadge = nil; [self save]; [self refreshPanel]; [self tick:nil];
}
- (void)settingsChangedScope:(NSString *)scope {
    scope = [scope isEqual:@"task"] ? @"task" : @"global";
    if ([scope isEqual:self.scope]) return;
    [self creditCurrentFocus];
    if (self.timer.running && [self.timer.phase isEqual:@"work"]) [self.timer pauseAt:Now()];
    if ([scope isEqual:@"task"]) {
        self.globalWorkRemaining = [self.timer workRemainingAt:Now()];
        self.scope = scope;
        [self loadSelectedTaskTime];
    } else {
        [self stashSelectedTaskTime];
        self.scope = scope;
        [self.timer loadWorkRemaining:self.globalWorkRemaining at:Now()];
    }
    self.taskStore.focusAnchorRemaining = -1;
    self.panelView.scope = self.scope;
    [self save]; [self refreshPanel]; [self tick:nil];
}
- (void)settingsChangedWork:(double)work breakMinutes:(double)rest {
    double oldWork = self.timer.workSeconds;
    [self.timer setWorkMinutes:work breakMinutes:rest];
    if (self.timer.workSeconds != oldWork) {
        for (NSDictionary *task in self.taskStore.tasks) {
            double value = [self.taskStore remainingForTaskID:task[@"id"]];
            if (value > self.timer.workSeconds) [self.taskStore setRemaining:self.timer.workSeconds forTaskID:task[@"id"]];
        }
        if (self.globalWorkRemaining > self.timer.workSeconds) self.globalWorkRemaining = -1;
    }
    if (!self.timer.running) self.taskStore.focusAnchorRemaining = -1;
    [self save]; [self refreshPanel]; [self tick:nil];
}
- (void)settingsChangedScale:(double)scale {
    self.uiScale = fmin(1.5, fmax(.5, scale));
    self.panelView.uiScale = self.uiScale;
    [self panelContentHeightChanged];
    if (self.panel.visible) [self placePanel];
    self.panelView.needsDisplay = YES;
    [self save];
}
- (void)settingsChangedVolume:(double)volume { self.volume = fmin(1, fmax(0, volume)); [self save]; }
- (void)settingsChangedSoundPack:(NSString *)pack { self.soundPack = pack ?: @"glass"; [self save]; }
- (void)settingsChangedNotify:(BOOL)notify { self.notify = notify; if (notify) [self requestNotifications]; [self save]; }
- (void)settingsPreviewSound { [self playSound:@"focus-end" gain:1]; }

#pragma mark Connected file

- (NSString *)signatureOfLinkedFile {
    struct stat info;
    if (!self.linkedPath || stat(self.linkedPath.fileSystemRepresentation, &info) != 0) return @"missing";
    return [NSString stringWithFormat:@"%llu-%lld-%ld.%ld", (unsigned long long)info.st_ino, (long long)info.st_size, (long)info.st_mtimespec.tv_sec, (long)info.st_mtimespec.tv_nsec];
}
- (void)reloadLinkedFile {
    self.linkedSignature = [self signatureOfLinkedFile];
    if (!self.linkedPath) { self.fileTasks = @[]; self.fileMissing = NO; return; }
    NSString *text = [NSString stringWithContentsOfFile:self.linkedPath encoding:NSUTF8StringEncoding error:nil];
    self.fileMissing = text == nil;
    NSArray<ShiroFileTask *> *parsed = text ? [ShiroLinkedFile tasksInText:text filePath:self.linkedPath] : @[];
    if (text) {
        // Forget the order of tasks that are no longer in the file (the daily note is replaced every morning).
        NSSet *present = [NSSet setWithArray:[parsed valueForKey:@"title"]];
        self.fileOrder = [self.fileOrder filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *title, NSDictionary *_) { return [present containsObject:title]; }]];
        for (NSString *title in self.fileGroups.allKeys) if (![present containsObject:title]) [self.fileGroups removeObjectForKey:title];
    }
    self.fileTasks = [ShiroLinkedFile tasks:parsed inOrder:self.fileOrder ?: @[] sections:self.fileGroups ?: @{}];
    if (self.taskStore) [self dropFileSelectionIfGone];
}
- (NSString *)linkedFileName { return self.linkedPath.lastPathComponent; }
- (void)settingsConnectFile {
    [self.settingsPopover close];
    NSOpenPanel *open = [NSOpenPanel openPanel];
    open.message = ShiroL(@"fileIntro");
    open.prompt = ShiroL(@"connectFile").length > 1 ? [ShiroL(@"connectFile") stringByReplacingOccurrencesOfString:@"…" withString:@""] : nil;
    UTType *markdown = [UTType typeWithFilenameExtension:@"md"];
    if (markdown) open.allowedContentTypes = @[markdown];
    open.canChooseDirectories = NO; open.allowsMultipleSelection = NO;
    open.directoryURL = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]];
    [NSApp activateIgnoringOtherApps:YES];
    if ([open runModal] != NSModalResponseOK || !open.URL) return;
    self.linkedPath = open.URL.path;
    self.fileCollapsed = NO;
    [self reloadLinkedFile];
    [self save]; [self refreshPanel];
    if (!self.panel.visible) [self togglePanel:nil];
}
- (void)settingsDisconnectFile {
    if (self.activeFileTitle) { self.fileMissing = NO; self.fileTasks = @[]; }
    self.linkedPath = nil;
    if (self.activeFileTitle) { [self stopFocusIfRunning]; self.activeFileTitle = nil; self.taskStore.activeTaskID = self.taskStore.firstOpenTask[@"id"]; [self loadSelectedTaskTime]; }
    [self reloadLinkedFile];
    [self save]; [self refreshPanel];
}
- (void)panelReorderBlocks:(NSArray<NSString *> *)keys {
    NSInteger index = 0;
    for (NSString *key in keys) {
        if ([key isEqual:@"file"]) { self.fileIndex = index; continue; }
        [self.taskStore moveSectionID:key toIndex:index++];
    }
    [self afterTaskChange];
}
// Marking a file task flips its "[ ]"/"[x]" in the file; the file is read again right before writing.
- (void)panelToggleFileTask:(NSInteger)index {
    if (!self.linkedPath || index < 0 || index >= (NSInteger)self.fileTasks.count) return;
    ShiroFileTask *task = self.fileTasks[(NSUInteger)index];
    NSString *text = [NSString stringWithContentsOfFile:self.linkedPath encoding:NSUTF8StringEncoding error:nil];
    NSString *next = text ? [ShiroLinkedFile text:text bySettingTask:task done:!task.done] : nil;
    if (next) {
        NSError *error = nil;
        if (![next writeToFile:self.linkedPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) NSLog(@"Cannot write %@: %@", self.linkedPath, error);
        else if (!task.done) { [self playReactionRow:3]; [self playSound:@"task-done" gain:.8]; }
    }
    [self reloadLinkedFile]; [self refreshPanel]; [self tick:nil];
}
- (void)panelSelectFileTask:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.fileTasks.count) return;
    ShiroFileTask *task = self.fileTasks[(NSUInteger)index];
    if (task.done || [task.title isEqual:self.activeFileTitle]) return;
    BOOL separate = [self.scope isEqual:@"task"];
    if (separate) { [self creditCurrentFocus]; [self stashSelectedTaskTime]; if (self.timer.running && [self.timer.phase isEqual:@"work"]) [self.timer pauseAt:Now()]; }
    self.activeFileTitle = task.title;
    [self keepFileSelection];
    if (separate) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelMoveFileTask:(NSInteger)index before:(NSInteger)beforeIndex section:(NSString *)section {
    NSInteger count = (NSInteger)self.fileTasks.count;
    if (index < 0 || index >= count) return;
    ShiroFileTask *moved = self.fileTasks[(NSUInteger)index];
    ShiroFileTask *before = beforeIndex >= 0 && beforeIndex < count ? self.fileTasks[(NSUInteger)beforeIndex] : nil;
    NSString *group = before ? before.section : (section ?: @"");
    self.fileOrder = [ShiroLinkedFile orderAfterMoving:moved before:before section:group shown:self.fileTasks];
    // Remember the group only when the task left the one it has in the file.
    NSString *home = nil;
    NSString *text = [NSString stringWithContentsOfFile:self.linkedPath encoding:NSUTF8StringEncoding error:nil];
    for (ShiroFileTask *t in text ? [ShiroLinkedFile tasksInText:text filePath:self.linkedPath] : @[]) if ([t.title isEqual:moved.title]) { home = t.section; break; }
    if (home && ![home isEqual:group]) self.fileGroups[moved.title] = group; else [self.fileGroups removeObjectForKey:moved.title];
    [self reloadLinkedFile]; [self save]; [self refreshPanel];
}
- (void)dropFileSelectionIfGone {
    if (!self.activeFileTitle || self.fileMissing) return;
    for (ShiroFileTask *task in self.fileTasks) if (!task.done && [task.title isEqual:self.activeFileTitle]) return;
    // The task was ticked, renamed or the day was replaced: fall back to the first open Shiro task.
    [self stopFocusIfRunning];
    self.activeFileTitle = nil;
    self.taskStore.activeTaskID = self.taskStore.firstOpenTask[@"id"];
    [self loadSelectedTaskTime];
}
- (void)panelToggleFileBlock { self.fileCollapsed = !self.fileCollapsed; [self save]; [self refreshPanel]; }
// The only write Shiro makes to the file: one "- [ ] text" line. The file is read again right before writing.
- (void)panelAddTaskToFile:(NSString *)title {
    if (!self.linkedPath) return;
    NSString *text = [NSString stringWithContentsOfFile:self.linkedPath encoding:NSUTF8StringEncoding error:nil];
    if (!text) { [self.panelView showToast:ShiroL(@"fileMissing")]; [self reloadLinkedFile]; [self refreshPanel]; return; }
    NSString *next = [ShiroLinkedFile text:text byAppendingTask:title];
    NSError *error = nil;
    if (![next writeToFile:self.linkedPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) NSLog(@"Cannot write %@: %@", self.linkedPath, error);
    [self reloadLinkedFile]; [self refreshPanel];
}
- (void)panelImportFileTask:(NSInteger)index toSection:(NSString *)sectionID before:(NSString *)beforeID {
    if (index < 0 || index >= (NSInteger)self.fileTasks.count) return;
    ShiroFileTask *source = self.fileTasks[(NSUInteger)index];
    NSString *before = self.taskStore.activeTaskID;
    NSString *created = [self.taskStore addTitle:source.title toSectionID:sectionID];
    if (!created) return;
    if (source.link.length) [self.taskStore setLink:source.link forTaskID:created];
    if (beforeID) [self.taskStore moveTaskID:created toSectionID:sectionID beforeTaskID:beforeID];
    [self.taskStore expandSectionID:sectionID];
    [self keepFileSelection];
    if (!before && self.taskStore.activeTaskID) [self loadSelectedTaskTime];
    [self afterTaskChange];
}
- (void)panelImportFileTask:(NSInteger)index fromRect:(NSRect)rect {
    if (!self.taskStore.sections.count) [self.taskStore addSectionTitle:ShiroL(@"defaultWork")];
    if (self.taskStore.sections.count == 1) { [self panelImportFileTask:index toSection:self.taskStore.sections.firstObject[@"id"] before:nil]; return; }
    NSMenu *menu = [[NSMenu alloc] init];
    for (NSDictionary *section in self.taskStore.sections) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:section[@"title"] action:@selector(importChosen:) keyEquivalent:@""];
        item.target = self; item.representedObject = @[@(index), section[@"id"]];
        [menu addItem:item];
    }
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMinX(rect), NSMaxY(rect) + 4) inView:self.panelView];
}
- (void)importChosen:(NSMenuItem *)item { [self panelImportFileTask:[item.representedObject[0] integerValue] toSection:item.representedObject[1] before:nil]; }

#pragma mark Background sound

// Keyboard sound plays only while focus is running (or for a short preview after it is switched on); it fades in and out.
- (void)updateAmbient {
    BOOL wanted = [self live] && self.ambient && self.ambientVolume > 0 &&
                  ((self.timer.running && [self.timer.phase isEqual:@"work"]) || Now() < self.ambientPreviewUntil);
    if (wanted) {
        if (!self.ambientPlayer) {
            NSURL *url = [NSBundle.mainBundle URLForResource:@"ambient-keyboard" withExtension:@"caf"];
            if (!url) return;
            self.ambientPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
            self.ambientPlayer.numberOfLoops = -1;
            [self.ambientPlayer prepareToPlay];
        }
        if (!self.ambientPlayer.playing) { self.ambientPlayer.volume = 0; [self.ambientPlayer play]; }
        if (fabs(self.ambientPlayer.volume - self.ambientVolume) > .01) [self.ambientPlayer setVolume:(float)self.ambientVolume fadeDuration:.8];
    } else if (self.ambientPlayer.playing && self.ambientPlayer.volume > 0) {
        [self.ambientPlayer setVolume:0 fadeDuration:.6];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.ambientPlayer.volume < .01) [self.ambientPlayer pause];
        });
    }
}
- (void)settingsChangedAmbient:(BOOL)on {
    self.ambient = on;
    // Switching it on outside focus plays three seconds so you hear what it is.
    if (on && !(self.timer.running && [self.timer.phase isEqual:@"work"])) self.ambientPreviewUntil = Now() + 3;
    [self save]; [self updateAmbient];
    self.status.menu = self.menu;
}
- (void)settingsChangedAmbientVolume:(double)volume {
    self.ambientVolume = fmin(1, fmax(0, volume));
    if (!(self.timer.running && [self.timer.phase isEqual:@"work"])) self.ambientPreviewUntil = Now() + 2;
    if (self.ambientPlayer.playing) self.ambientPlayer.volume = (float)self.ambientVolume;
    [self save]; [self updateAmbient];
}
- (void)toggleAmbientFromMenu:(id)sender { [self settingsChangedAmbient:!self.ambient]; [self.settingsController refresh]; }

#pragma mark Sound and notifications

- (void)playSound:(NSString *)event gain:(double)gain {
    if (![self live] || self.volume <= 0) return;
    if (!self.sounds) self.sounds = [NSMutableDictionary dictionary];
    NSString *name = [NSString stringWithFormat:@"%@-%@", self.soundPack, event];
    NSSound *sound = self.sounds[name];
    if (!sound) {
        NSString *path = [NSBundle.mainBundle pathForResource:name ofType:@"wav"];
        sound = path ? [[NSSound alloc] initWithContentsOfFile:path byReference:YES] : [NSSound soundNamed:@"Glass"];
        if (sound) self.sounds[name] = sound;
    }
    [sound stop];
    sound.volume = (float)fmin(1, self.volume * gain);
    [sound play];
}
- (BOOL)canNotify { return [self live] && NSBundle.mainBundle.bundleIdentifier.length > 0; }
- (void)requestNotifications {
    if (![self canNotify]) return;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = self;
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError *error) {}];
}
- (void)postNotificationTitle:(NSString *)title body:(NSString *)body {
    if (!self.notify || ![self canNotify]) return;
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title; content.body = body;   // Shiro plays its own sound at the chosen volume.
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"shiro-interval" content:content trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList);
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    if (!self.panel.visible) [self togglePanel:nil];
    completionHandler();
}

#pragma mark Menu and storage

- (void)focusTaskInput:(id)sender {
    if (!self.panel.visible) [self togglePanel:nil];
    NSString *section = self.taskStore.sections.firstObject[@"id"];
    if (!section) section = [self.taskStore addSectionTitle:ShiroL(@"defaultWork")];
    [self refreshPanel];
    [self.panelView beginAddingTaskToSection:section];
}
- (void)selectFromMenu:(NSMenuItem *)item { [self panelSelectTask:item.representedObject]; }
- (void)playFromMenu:(id)sender { [self panelToggleTimer]; }
- (void)showPet:(id)sender { [self.petWindow orderFrontRegardless]; }
- (void)hidePet:(id)sender { [self.petWindow orderOut:nil]; [self panelClose]; }
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (NSMenu *)menu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Широ"];
    NSArray *items = @[@[ShiroL(@"menuPanel"), NSStringFromSelector(@selector(togglePanel:))],
                       @[ShiroL(@"menuPlay"), NSStringFromSelector(@selector(playFromMenu:))],
                       @[ShiroL(@"menuShow"), NSStringFromSelector(@selector(showPet:))],
                       @[ShiroL(@"menuHide"), NSStringFromSelector(@selector(hidePet:))],
                       @[ShiroL(@"menuQuit"), NSStringFromSelector(@selector(quit:))]];
    for (NSArray *item in items) {
        NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:item[0] action:NSSelectorFromString(item[1]) keyEquivalent:@""];
        entry.target = self; [menu addItem:entry];
    }
    [menu insertItem:[NSMenuItem separatorItem] atIndex:2];
    NSMenuItem *ambient = [[NSMenuItem alloc] initWithTitle:ShiroL(@"menuAmbient") action:@selector(toggleAmbientFromMenu:) keyEquivalent:@""];
    ambient.target = self; ambient.state = self.ambient ? NSControlStateValueOn : NSControlStateValueOff;
    [menu insertItem:ambient atIndex:2];
    NSMenuItem *taskMenu = [[NSMenuItem alloc] initWithTitle:ShiroL(@"tasks") action:nil keyEquivalent:@""];
    NSMenu *submenu = [[NSMenu alloc] initWithTitle:ShiroL(@"tasks")];
    NSMenuItem *add = [[NSMenuItem alloc] initWithTitle:ShiroL(@"menuAddTask") action:@selector(focusTaskInput:) keyEquivalent:@""];
    add.target = self; [submenu addItem:add];
    NSInteger shown = 0;
    for (NSDictionary *section in self.taskStore.sections) for (NSDictionary *task in [self.taskStore openTasksInSectionID:section[@"id"]]) {
        if (shown >= 8) continue;
        shown++;
        NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:task[@"title"] action:@selector(selectFromMenu:) keyEquivalent:@""];
        entry.representedObject = task[@"id"]; entry.target = self;
        entry.state = [self.taskStore.activeTaskID isEqual:task[@"id"]] ? NSControlStateValueOn : NSControlStateValueOff;
        [submenu addItem:entry];
    }
    taskMenu.submenu = submenu; [menu insertItem:taskMenu atIndex:3];
    return menu;
}
- (void)save {
    if (self.renderPath) return;
    if ([self.scope isEqual:@"task"]) [self stashSelectedTaskTime];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:self.timer.state forKey:@"timer"];
    [d setObject:self.taskStore.state forKey:@"checklist"];
    [d setObject:self.themeID forKey:@"theme"];
    [d setObject:self.language forKey:@"language"];
    [d setObject:self.scope forKey:@"timerScope"];
    [d setObject:self.soundPack forKey:@"soundPack"];
    [d setDouble:self.volume forKey:@"volume"];
    [d setBool:self.notify forKey:@"notify"];
    [d setBool:self.ambient forKey:@"ambient"];
    [d setDouble:self.ambientVolume forKey:@"ambientVolume"];
    [d setDouble:self.uiScale forKey:@"uiScale"];
    if (self.linkedPath) [d setObject:self.linkedPath forKey:@"linkedFile"]; else [d removeObjectForKey:@"linkedFile"];
    [d setBool:self.fileCollapsed forKey:@"linkedFileCollapsed"];
    [d setInteger:self.fileIndex forKey:@"linkedFileIndex"];
    if (self.activeFileTitle) [d setObject:self.activeFileTitle forKey:@"activeFileTask"]; else [d removeObjectForKey:@"activeFileTask"];
    [d setObject:self.fileRemaining ?: @{} forKey:@"fileTaskRemaining"];
    [d setObject:self.fileOrder ?: @[] forKey:@"fileTaskOrder"];
    [d setObject:self.fileGroups ?: @{} forKey:@"fileTaskGroups"];
    [d setDouble:self.globalWorkRemaining forKey:@"globalWorkRemaining"];
    [d setDouble:self.petWindow.frame.origin.x forKey:@"petX"];
    [d setDouble:self.petWindow.frame.origin.y forKey:@"petY"];
}
- (void)applicationWillTerminate:(NSNotification *)notification { [self creditCurrentFocus]; [self save]; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag { [self showPet:nil]; return YES; }
@end

#pragma mark - Command-line checks and renders

static ShiroTaskStore *DemoStore(void) {
    ShiroTaskStore *store = [[ShiroTaskStore alloc] initWithState:@{@"sections":@[], @"tasks":@[], @"version":@6}];
    BOOL en = [ShiroLanguage() isEqual:@"en"];
    NSString *shiro = [store addSectionTitle:@"На сегодня"], *work = [store addSectionTitle:en ? @"Work" : @"Работа"], *home = [store addSectionTitle:en ? @"Personal" : @"Личное"];
    NSString *a = [store addTitle:en ? @"Sort my notes" : @"Разобрать заметки" toSectionID:shiro];
    NSString *b = [store addTitle:en ? @"Draft a plan" : @"Набросать план" toSectionID:shiro];
    NSString *c = [store addTitle:en ? @"Choose a playlist" : @"Выбрать плейлист" toSectionID:shiro];
    [store addTitle:en ? @"Make two layouts" : @"Сделать два макета" toSectionID:work];
    NSString *e = [store addTitle:en ? @"Collect references" : @"Собрать референсы" toSectionID:work];
    [store addTitle:en ? @"Buy tickets" : @"Купить билеты" toSectionID:home];
    NSString *f = [store addTitle:en ? @"Find an interesting idea, collect references and turn them into a small project" : @"Найти интересную идею, собрать референсы и превратить всё это в небольшой проект" toSectionID:work];
    [store setLink:@"figma.com/file/shiro-0-6" forTaskID:f];
    [store setLink:@"notion.so/shiro-references" forTaskID:e];
    [store toggleTaskID:c]; [store toggleTaskID:e];
    [store setRemaining:740 forTaskID:b];
    store.doneCollapsed = NO;
    (void)a;
    return store;
}

static int RenderView(NSView *view, NSString *path, CGFloat scale) {
    NSInteger width = (NSInteger)(view.bounds.size.width * scale), height = (NSInteger)(view.bounds.size.height * scale);
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *base = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef context = base.CGContext;
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, -scale);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
    ShiroDrawViewTree(view);
    [NSGraphicsContext restoreGraphicsState];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:path atomically:YES] ? 0 : 4;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        ShiroApp *delegate = [[ShiroApp alloc] init];
        if (argc == 2 && strcmp(argv[1], "--check-playback") == 0) {
            delegate.renderPath = @"test"; delegate.scope = @"global"; delegate.volume = 0;
            delegate.timer = [[ShiroTimer alloc] initWithState:nil now:Now()];
            delegate.taskStore = [[ShiroTaskStore alloc] initWithState:nil];
            delegate.pet = [[PetView alloc] initWithFrame:NSMakeRect(0, 0, 192, 212)]; delegate.pet.owner = delegate;
            [delegate panelToggleTimer];
            double start = delegate.motionStartedAt; NSTimer *animation = delegate.animation;
            for (NSInteger i = 0; i < 20; i++) [delegate tick:nil];
            if (delegate.motionStartedAt != start || delegate.animation != animation || delegate.pet.row != 7) return 10;
            [delegate panelToggleTimer];
            if (delegate.pet.row != 0 || delegate.timer.running) return 11;
            [delegate panelToggleTimer]; delegate.timer.deadline = Now() - 1; [delegate tick:nil];
            if (delegate.pet.row != 8 || ![delegate.timer.phase isEqual:@"break"] || delegate.timer.running) return 12;
            delegate.reactionUntil = 0; [delegate tick:nil];
            if (delegate.pet.row != 0) return 13;
            [delegate panelToggleTimer];
            if (delegate.pet.row != 5 || !delegate.timer.running) return 14;
            start = delegate.motionStartedAt; animation = delegate.animation;
            for (NSInteger i = 0; i < 20; i++) [delegate tick:nil];
            if (delegate.motionStartedAt != start || delegate.animation != animation) return 15;
            delegate.reactionUntil = 0; delegate.timer.deadline = Now() - 1; [delegate tick:nil];
            if (delegate.pet.row != 3 || ![delegate.timer.phase isEqual:@"work"] || delegate.timer.running) return 16;
            [delegate.animation invalidate];
            NSLog(@"PASS: clock refresh never restarts motion; focus → glasses → waiting break → scare → wave");
            return 0;
        }
        if (argc == 2 && strcmp(argv[1], "--check-ui-copy") == 0) {
            NSArray *missing = ShiroMissingTranslations();
            if (missing.count) { NSLog(@"FAIL: missing translations %@", missing); return 5; }
            NSArray *expect = @[@[@NO, @NO, @"start"], @[@NO, @YES, @"resume"], @[@YES, @YES, @"pause"]];
            for (NSString *language in @[@"ru", @"en"]) {
                ShiroSetLanguage(language);
                for (NSString *phase in @[@"work", @"break"]) for (NSArray *state in expect) {
                    ShiroTimer *timer = [[ShiroTimer alloc] initWithState:@{@"phase":phase} now:Now()];
                    if ([state[1] boolValue]) timer.remaining = [timer durationOfPhase:phase] * .6;
                    if ([state[0] boolValue]) [timer startAt:Now()];
                    if (![ShiroMainLabel(timer, Now()) isEqual:ShiroL(state[2])]) return 6;
                }
                // Mode words share the head row with the time and the reset button.
                NSFont *font = ShiroTextFont(14, 600);
                CGFloat width = [ShiroL(@"focus") sizeWithAttributes:@{NSFontAttributeName:font}].width + [ShiroL(@"break") sizeWithAttributes:@{NSFontAttributeName:font}].width;
                if (width > 150) return 7;
            }
            // ⌘V must reach the text field with a Russian layout too (V key gives "м").
            [NSApplication sharedApplication];
            ShiroPanelWindow *window = [[ShiroPanelWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
            ShiroPasteProbe *probe = [[ShiroPasteProbe alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
            window.contentView = probe; [window makeFirstResponder:probe];
            for (NSString *letter in @[@"м", @"v"]) {
                NSEvent *key = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:0 context:nil characters:letter charactersIgnoringModifiers:letter isARepeat:NO keyCode:9];
                if (![window performKeyEquivalent:key]) return 11;
            }
            if (probe.pasted != 2) return 12;
            // A click on the circle completes the task; a click on the text selects it.
            ShiroRegisterFonts();
            delegate.renderPath = @"test"; delegate.themeID = @"pastel"; delegate.scope = @"global"; delegate.uiScale = 1;
            delegate.timer = [[ShiroTimer alloc] initWithState:nil now:Now()];
            delegate.taskStore = DemoStore();
            ShiroPanelView *panel = [delegate makePanelView];
            panel.frame = NSMakeRect(0, 0, ShiroPanelWidth, panel.preferredHeight);
            NSBitmapImageRep *rep = [panel bitmapImageRepForCachingDisplayInRect:panel.bounds];
            [panel cacheDisplayInRect:panel.bounds toBitmapImageRep:rep];
            CGFloat firstRow = 154 + 44 + 46 + 20;
            if (![[panel actionAt:NSMakePoint(64, firstRow)] isEqual:@"check"]) return 13;
            if (![[panel actionAt:NSMakePoint(220, firstRow)] isEqual:@"row"]) return 14;
            if (![[panel actionAt:NSMakePoint(ShiroPanelWidth - 25, firstRow)] isEqual:@"more"]) return 15;
            ShiroSetLanguage(@"ru");
            if (![ShiroActiveCount(1) isEqual:@"1 активная"] || ![ShiroActiveCount(3) isEqual:@"3 активные"] || ![ShiroActiveCount(11) isEqual:@"11 активных"]) return 8;
            if (![ShiroDeleteSectionQuestion(@"Работа", 21) containsString:@"21 задачей"]) return 9;
            if ([ShiroTheme all].count != 8 || ![[ShiroTheme themeWithIdentifier:@"shiro"].number isEqual:@"00"]) return 10;
            NSLog(@"PASS: translations complete, button labels for 6 timer states in 2 languages, plurals, 8 schemes, ⌘V in any layout, task circle completes");
            return 0;
        }
        if (argc >= 3 && strcmp(argv[1], "--render-panel") == 0) {
            // --render-panel out.png [theme] [ru|en] [global|task] [editing]
            ShiroRegisterFonts();
            ShiroSetLanguage(argc > 4 ? [NSString stringWithUTF8String:argv[4]] : @"ru");
            delegate.renderPath = [NSString stringWithUTF8String:argv[2]];
            delegate.themeID = argc > 3 ? [NSString stringWithUTF8String:argv[3]] : @"pastel";
            delegate.scope = argc > 5 ? [NSString stringWithUTF8String:argv[5]] : @"global";
            delegate.timer = [[ShiroTimer alloc] initWithState:nil now:Now()];
            delegate.timer.remaining = 1200 - 7 * 60 - 18;
            delegate.taskStore = DemoStore();
            NSString *file = NSProcessInfo.processInfo.environment[@"SHIRO_RENDER_FILE"];   // read only, for previews
            if (file.length) { delegate.linkedPath = file; [delegate reloadLinkedFile]; delegate.taskStore.doneCollapsed = YES; }
            NSString *activeFile = NSProcessInfo.processInfo.environment[@"SHIRO_RENDER_ACTIVE_FILE"];
            if (activeFile.length) { delegate.activeFileTitle = activeFile; [delegate keepFileSelection]; }
            delegate.uiScale = ShiroScaleSteps().firstObject.doubleValue;
            ShiroPanelView *view = [delegate makePanelView];
            view.frame = NSMakeRect(0, 0, ShiroPanelWidth * delegate.uiScale, view.preferredHeight);
            if (argc > 6) {
                [view beginAddingTaskToSection:delegate.taskStore.sections.firstObject[@"id"]];
                view.frame = NSMakeRect(0, 0, ShiroPanelWidth * delegate.uiScale, view.preferredHeight);
            }
            [view display];
            return RenderView(view, delegate.renderPath, 2);
        }
        if (argc >= 3 && strcmp(argv[1], "--render-settings") == 0) {
            // --render-settings out.png [theme] [ru|en]
            ShiroRegisterFonts();
            ShiroSetLanguage(argc > 4 ? [NSString stringWithUTF8String:argv[4]] : @"ru");
            delegate.renderPath = [NSString stringWithUTF8String:argv[2]];
            delegate.themeID = argc > 3 ? [NSString stringWithUTF8String:argv[3]] : @"pastel";
            delegate.language = ShiroLanguage(); delegate.uiScale = ShiroScaleSteps().firstObject.doubleValue; delegate.scope = @"global"; delegate.soundPack = @"glass"; delegate.volume = .8; delegate.notify = YES;
            delegate.timer = [[ShiroTimer alloc] initWithState:nil now:Now()];
            delegate.linkedPath = NSProcessInfo.processInfo.environment[@"SHIRO_RENDER_FILE"];
            ShiroSettingsController *controller = [[ShiroSettingsController alloc] init];
            controller.delegate = delegate;
            NSView *view = controller.view;
            [controller refresh];
            NSWindow *host = [[NSWindow alloc] initWithContentRect:view.frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
            host.appearance = view.appearance; host.backgroundColor = view.appearance == [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua] ? [NSColor colorWithWhite:.16 alpha:1] : [NSColor colorWithWhite:.96 alpha:1];
            host.contentView = view;
            [view display];
            NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
            return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:delegate.renderPath atomically:YES] ? 0 : 4;
        }
        if ((argc == 4 && strcmp(argv[1], "--render-offscreen") == 0) || (argc == 5 && strcmp(argv[1], "--render-motion") == 0)) {
            ShiroRegisterFonts();
            delegate.renderPath = [NSString stringWithUTF8String:argv[2]];
            delegate.themeID = NSProcessInfo.processInfo.environment[@"SHIRO_RENDER_THEME"] ?: @"pastel";
            delegate.taskStore = DemoStore();
            NSInteger row = atoi(argv[3]);
            if (row != 0 && row != 3 && row != 5 && row != 7 && row != 8) return 2;
            delegate.timer = [[ShiroTimer alloc] initWithState:nil now:Now()];
            if (row == 5 || row == 8) { delegate.timer.phase = @"break"; delegate.timer.remaining = 420; }
            if (row != 0) [delegate.timer startAt:Now()];
            if (row == 7) delegate.timer.deadline = Now() + 912;
            if (row == 5) delegate.timer.deadline = Now() + 246;
            PetView *pet = [[PetView alloc] initWithFrame:NSMakeRect(0, 0, 192, 212)];
            pet.owner = delegate; pet.row = row;
            pet.rig = [[ShiroRig alloc] initWithDirectory:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"animations"]];
            if (!pet.rig) return 4;
            pet.manualTime = argc == 5 ? atof(argv[4]) : 0;
            NSString *petScale = NSProcessInfo.processInfo.environment[@"SHIRO_RENDER_SCALE"];
            return RenderView(pet, delegate.renderPath, petScale.length ? petScale.doubleValue : 1);
        }
        NSApplication *app = NSApplication.sharedApplication;
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
