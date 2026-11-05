#import <Cocoa/Cocoa.h>
@class ShiroTimer, ShiroTaskStore, ShiroFileTask;

// ---------- Language ----------
void ShiroSetLanguage(NSString *language);   // @"ru" or @"en"
NSString *ShiroLanguage(void);
NSString *ShiroL(NSString *key);
NSString *ShiroActiveCount(NSInteger count);
NSString *ShiroDeleteSectionQuestion(NSString *name, NSInteger count);
NSString *ShiroClearDoneQuestion(NSInteger count);
NSString *ShiroMainLabel(ShiroTimer *timer, NSTimeInterval now);   // Start / Pause / Resume
NSArray<NSString *> *ShiroMissingTranslations(void);

// ---------- Fonts ----------
void ShiroRegisterFonts(void);
NSFont *ShiroDisplayFont(CGFloat size, CGFloat weight);   // Unbounded: numbers and logo
NSFont *ShiroTextFont(CGFloat size, CGFloat weight);      // Onest: everything else

// ---------- Colour schemes ----------
@interface ShiroTheme : NSObject
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *number;
@property(nonatomic, strong, readonly) NSColor *background, *ink, *muted, *popover, *popoverInk;
@property(nonatomic, strong, readonly) NSColor *headBackground, *headInk, *headMuted;
@property(nonatomic, strong, readonly) NSArray<NSColor *> *bandFills, *bandInks;
@property(nonatomic, readonly) BOOL dark;
+ (NSArray<ShiroTheme *> *)all;
+ (ShiroTheme *)themeWithIdentifier:(NSString *)identifier;
- (NSColor *)bandFillAt:(NSInteger)index;
- (NSColor *)bandInkAt:(NSInteger)index;
@end

// ---------- Panel ----------
@protocol ShiroPanelDelegate <NSObject>
- (void)panelToggleTimer;
- (void)panelResetTimer;
- (void)panelSwitchToPhase:(NSString *)phase;
- (void)panelSelectTask:(NSString *)taskID;
- (void)panelToggleTask:(NSString *)taskID;
- (void)panelAddTask:(NSString *)title toSection:(NSString *)sectionID;
- (NSString *)panelAddSection:(NSString *)title;
- (void)panelRenameTask:(NSString *)taskID title:(NSString *)title;
- (void)panelRenameSection:(NSString *)sectionID title:(NSString *)title;
- (void)panelDeleteTask:(NSString *)taskID;
- (void)panelMoveTask:(NSString *)taskID toSection:(NSString *)sectionID before:(NSString *)beforeID;
- (void)panelSetLink:(NSString *)link forTask:(NSString *)taskID;
- (void)panelToggleDoneList;
- (void)panelClearDone;
- (void)panelAddTaskToFile:(NSString *)title;
- (void)panelImportFileTask:(NSInteger)index toSection:(NSString *)sectionID before:(NSString *)beforeID;
- (void)panelImportFileTask:(NSInteger)index fromRect:(NSRect)rect;   // asks which section
- (void)panelToggleFileBlock;
- (void)panelToggleFileTask:(NSInteger)index;
- (void)panelSelectFileTask:(NSInteger)index;
- (void)panelMoveFileTask:(NSInteger)index before:(NSInteger)beforeIndex section:(NSString *)section;   // -1: to the end of the group
- (void)panelReorderBlocks:(NSArray<NSString *> *)keys;   // section ids and @"file", in the new order
- (void)panelDeleteSection:(NSString *)sectionID;
- (void)panelToggleSection:(NSString *)sectionID;
- (void)panelExpandSection:(NSString *)sectionID;
- (void)panelMoveSection:(NSString *)sectionID toIndex:(NSInteger)index;
- (void)panelShowSettingsFromRect:(NSRect)rect;
- (void)panelClose;
- (void)panelContentHeightChanged;
@end

@interface ShiroPanelView : NSView <NSTextFieldDelegate>
@property(nonatomic, weak) id<ShiroPanelDelegate> delegate;
@property(nonatomic, weak) ShiroTimer *timer;
@property(nonatomic, weak) ShiroTaskStore *store;
@property(nonatomic, strong) ShiroTheme *theme;
@property(nonatomic, copy) NSString *scope;   // @"global" or @"task"
@property(nonatomic) NSTimeInterval now;
@property(nonatomic) CGFloat uiScale;      // 1 = ShiroPanelWidth points wide
// Connected Markdown file: nil name means no file is connected.
@property(nonatomic, copy) NSString *fileName;
@property(nonatomic, strong) NSArray<ShiroFileTask *> *fileTasks;
@property(nonatomic) BOOL fileMissing, fileCollapsed;
@property(nonatomic) NSInteger fileIndex;   // the file block's place among the sections
@property(nonatomic, copy) NSString *activeFileTitle;   // the current task when it comes from the file
- (CGFloat)preferredHeight;
- (void)reloadContent;        // tasks or theme changed
- (void)refreshTimer;         // time changed
- (void)showToast:(NSString *)text;
- (void)beginAddingTaskToSection:(NSString *)sectionID;
- (NSString *)actionAt:(NSPoint)point;   // for checks: what a click at this point (window coordinates at scale 1) would do
@end

// ---------- Settings ----------
@protocol ShiroSettingsDelegate <NSObject>
@property(nonatomic, copy) NSString *themeID, *language, *scope, *soundPack;
@property(nonatomic) double volume, uiScale;
@property(nonatomic) BOOL notify, ambient;
@property(nonatomic) double ambientVolume;
- (double)workMinutes;
- (double)breakMinutes;
- (void)settingsChangedTheme:(NSString *)themeID;
- (void)settingsChangedLanguage:(NSString *)language;
- (void)settingsChangedScope:(NSString *)scope;
- (void)settingsChangedWork:(double)work breakMinutes:(double)rest;
- (void)settingsChangedVolume:(double)volume;
- (void)settingsChangedScale:(double)scale;
- (void)settingsChangedSoundPack:(NSString *)pack;
- (void)settingsChangedNotify:(BOOL)notify;
- (void)settingsPreviewSound;
- (void)settingsChangedAmbient:(BOOL)on;
- (void)settingsChangedAmbientVolume:(double)volume;
- (NSString *)linkedFileName;
- (void)settingsConnectFile;
- (void)settingsDisconnectFile;
@end

@interface ShiroSettingsController : NSViewController
@property(nonatomic, weak) id<ShiroSettingsDelegate> delegate;
- (void)refresh;
@end

extern const CGFloat ShiroPanelWidth;
NSArray<NSNumber *> *ShiroScaleSteps(void);   // window sizes S, M, L
void ShiroDrawViewTree(NSView *view);
