#import "MixUI.h"
#import "TimerModel.h"
#import "TaskModel.h"
#import "LinkedFile.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CoreText/CoreText.h>
#include <math.h>

#pragma mark - Language

static NSString *gLanguage = @"ru";
void ShiroSetLanguage(NSString *language) { gLanguage = [language isEqual:@"en"] ? @"en" : @"ru"; }
NSString *ShiroLanguage(void) { return gLanguage; }

static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *Strings(void) {
    static NSDictionary *strings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        strings = @{
            @"ru": @{
                @"focus":@"Фокус", @"break":@"Перерыв", @"start":@"Начать", @"pause":@"Пауза", @"resume":@"Продолжить", @"reset":@"Сбросить",
                @"tasks":@"Задачи", @"addSection":@"+ раздел", @"settings":@"Настройки", @"hide":@"Скрыть окно",
                @"theme":@"Оформление", @"timer":@"Таймер", @"scopeGlobal":@"Общий для всех задач", @"scopeTask":@"Свой у каждой задачи",
                @"helpGlobal":@"Выбор задачи не меняет время.", @"helpTask":@"У задачи сохраняется своё время, при выборе другой отсчёт встаёт на паузу.",
                @"workMin":@"Фокус, мин", @"breakMin":@"Перерыв, мин", @"volume":@"Громкость", @"sound":@"Звук",
                @"glass":@"Стекло", @"wood":@"Дерево", @"air":@"Воздух", @"listen":@"Послушать",
                @"notify":@"Уведомлять в конце интервала", @"ambient":@"Звук клавиатуры во время фокуса", @"ambientVolume":@"Громкость фона", @"menuAmbient":@"Звук клавиатуры", @"language":@"Язык", @"windowSize":@"Размер окна",
                @"rename":@"Переименовать", @"delete":@"Удалить", @"attachLink":@"Прикрепить ссылку", @"editLink":@"Изменить ссылку", @"removeLink":@"Убрать ссылку", @"linkPlaceholder":@"Ссылка, например figma.com/…", @"openLink":@"Открыть ссылку", @"doneList":@"Завершённые", @"clearDone":@"Очистить", @"backToActive":@"Вернуть в работу", @"deleteForever":@"Удалить навсегда", @"addToFile":@"Добавить в файл", @"importToShiro":@"Добавить в Широ", @"inShiro":@"Уже в Широ", @"fileMissing":@"Файл не найден, Широ ждёт, пока он появится", @"fileEmpty":@"В файле пока нет задач", @"fileTitle":@"Файл задач", @"fileNone":@"Не подключён", @"connectFile":@"Подключить файл…", @"disconnectFile":@"Отключить", @"fileIntro":@"Выберите md-файл, например из Obsidian. Широ покажет его задачи отдельным блоком и будет дописывать туда новые.\nЗадача — строка «- [ ] текст», раздел — «## Название». Новые задачи попадают в «## Всплыло за день», если такой раздел есть, иначе в первый. Остальное в файле Широ не меняет.", @"renameSection":@"Переименовать раздел", @"deleteSection":@"Удалить раздел",
                @"cancel":@"Отмена", @"add":@"Добавить", @"createSection":@"Создать раздел", @"save":@"Сохранить",
                @"newTask":@"Новая задача", @"sectionName":@"Название раздела", @"taskName":@"Название задачи", @"empty":@"Пока пусто",
                @"markDone":@"Отметить выполненной", @"reopen":@"Вернуть задачу", @"taskActions":@"Действия с задачей",
                @"sectionActions":@"Действия с разделом", @"addTaskTo":@"Добавить задачу в раздел", @"collapse":@"Свернуть раздел", @"expand":@"Развернуть раздел",
                @"pickTask":@"Сначала выбери задачу",
                @"focusDone":@"Фокус завершён", @"focusDoneBody":@"Перерыв ждёт запуска",
                @"breakDone":@"Перерыв завершён", @"breakDoneBody":@"Фокус ждёт запуска",
                @"menuPanel":@"Таймер и задачи", @"menuPlay":@"Старт / пауза", @"menuShow":@"Показать Широ", @"menuHide":@"Скрыть Широ",
                @"menuQuit":@"Выйти", @"menuAddTask":@"Добавить задачу…",
                @"defaultWork":@"Работа", @"defaultPersonal":@"Личное", @"window":@"Окно Широ"
            },
            @"en": @{
                @"focus":@"Focus", @"break":@"Break", @"start":@"Start", @"pause":@"Pause", @"resume":@"Resume", @"reset":@"Reset",
                @"tasks":@"Tasks", @"addSection":@"+ section", @"settings":@"Settings", @"hide":@"Hide window",
                @"theme":@"Theme", @"timer":@"Timer", @"scopeGlobal":@"One timer for all tasks", @"scopeTask":@"Separate timer per task",
                @"helpGlobal":@"Picking a task doesn’t change the time.", @"helpTask":@"Each task keeps its own time. Picking another task pauses the count.",
                @"workMin":@"Focus, min", @"breakMin":@"Break, min", @"volume":@"Volume", @"sound":@"Sound",
                @"glass":@"Glass", @"wood":@"Wood", @"air":@"Air", @"listen":@"Play",
                @"notify":@"Notify when an interval ends", @"ambient":@"Keyboard sound while focusing", @"ambientVolume":@"Background volume", @"menuAmbient":@"Keyboard sound", @"language":@"Language", @"windowSize":@"Window size",
                @"rename":@"Rename", @"delete":@"Delete", @"attachLink":@"Attach link", @"editLink":@"Edit link", @"removeLink":@"Remove link", @"linkPlaceholder":@"Link, e.g. figma.com/…", @"openLink":@"Open link", @"doneList":@"Done", @"clearDone":@"Clear", @"backToActive":@"Back to active", @"deleteForever":@"Delete forever", @"addToFile":@"Add to the file", @"importToShiro":@"Add to Shiro", @"inShiro":@"Already in Shiro", @"fileMissing":@"File not found; Shiro waits for it to come back", @"fileEmpty":@"No tasks in the file yet", @"fileTitle":@"Task file", @"fileNone":@"Not connected", @"connectFile":@"Connect file…", @"disconnectFile":@"Disconnect", @"fileIntro":@"Pick a Markdown file, for example from Obsidian. Shiro shows its tasks as a separate block and adds new ones to it.\nA task is a line “- [ ] text”, a section is “## Name”. New tasks go to “## Всплыло за день” if the file has it, otherwise to the first section. Shiro changes nothing else in the file.", @"renameSection":@"Rename section", @"deleteSection":@"Delete section",
                @"cancel":@"Cancel", @"add":@"Add", @"createSection":@"Create section", @"save":@"Save",
                @"newTask":@"New task", @"sectionName":@"Section name", @"taskName":@"Task name", @"empty":@"Nothing here yet",
                @"markDone":@"Mark as done", @"reopen":@"Reopen task", @"taskActions":@"Task actions",
                @"sectionActions":@"Section actions", @"addTaskTo":@"Add a task to", @"collapse":@"Collapse section", @"expand":@"Expand section",
                @"pickTask":@"Pick a task first",
                @"focusDone":@"Focus done", @"focusDoneBody":@"Your break is ready to start",
                @"breakDone":@"Break over", @"breakDoneBody":@"Focus is ready to start",
                @"menuPanel":@"Timer and tasks", @"menuPlay":@"Start / pause", @"menuShow":@"Show Shiro", @"menuHide":@"Hide Shiro",
                @"menuQuit":@"Quit", @"menuAddTask":@"Add task…",
                @"defaultWork":@"Work", @"defaultPersonal":@"Personal", @"window":@"Shiro window"
            }
        };
    });
    return strings;
}
NSString *ShiroL(NSString *key) { return Strings()[gLanguage][key] ?: Strings()[@"ru"][key] ?: key; }
NSString *ShiroActiveCount(NSInteger n) {
    if ([gLanguage isEqual:@"en"]) return [NSString stringWithFormat:@"%ld active", (long)n];
    NSInteger a = n % 10, b = n % 100;
    NSString *word = a == 1 && b != 11 ? @"активная" : (a >= 2 && a <= 4 && (b < 10 || b >= 20)) ? @"активные" : @"активных";
    return [NSString stringWithFormat:@"%ld %@", (long)n, word];
}
NSString *ShiroDeleteSectionQuestion(NSString *name, NSInteger n) {
    if ([gLanguage isEqual:@"en"]) return [NSString stringWithFormat:@"Delete “%@” and its %ld %@?", name, (long)n, n == 1 ? @"task" : @"tasks"];
    BOOL one = n % 10 == 1 && n % 100 != 11;
    return [NSString stringWithFormat:@"Удалить «%@» вместе с %ld %@?", name, (long)n, one ? @"задачей" : @"задачами"];
}

NSString *ShiroClearDoneQuestion(NSInteger n) {
    if ([gLanguage isEqual:@"en"]) return [NSString stringWithFormat:@"Delete %ld done %@ forever?", (long)n, n == 1 ? @"task" : @"tasks"];
    NSInteger a = n % 10, b = n % 100;
    NSString *words = a == 1 && b != 11 ? @"завершённую задачу" : (a >= 2 && a <= 4 && (b < 10 || b >= 20)) ? @"завершённые задачи" : @"завершённых задач";
    return [NSString stringWithFormat:@"Удалить %ld %@ навсегда?", (long)n, words];
}
NSString *ShiroMainLabel(ShiroTimer *timer, NSTimeInterval now) {
    return ShiroL(timer.running ? @"pause" : [timer isPartialAt:now] ? @"resume" : @"start");
}
NSArray<NSString *> *ShiroMissingTranslations(void) {
    NSMutableArray *missing = [NSMutableArray array];
    NSDictionary *ru = Strings()[@"ru"], *en = Strings()[@"en"];
    for (NSString *key in ru) if (![en[key] length]) [missing addObject:[@"en:" stringByAppendingString:key]];
    for (NSString *key in en) if (![ru[key] length]) [missing addObject:[@"ru:" stringByAppendingString:key]];
    return missing;
}

#pragma mark - Fonts

void ShiroRegisterFonts(void) {
    for (NSString *name in @[@"Unbounded-Variable", @"Onest-Variable"]) {
        NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:@"ttf"];
        if (url) CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
    }
}
static NSFont *VariableFont(NSString *family, CGFloat size, CGFloat weight) {
    static NSMutableDictionary *cache;
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSString *key = [NSString stringWithFormat:@"%@-%.1f-%.0f", family, size, weight];
    if (cache[key]) return cache[key];
    NSFontDescriptor *descriptor = [NSFontDescriptor fontDescriptorWithFontAttributes:@{NSFontFamilyAttribute:family}];
    descriptor = [descriptor fontDescriptorByAddingAttributes:@{NSFontVariationAttribute:@{@(0x77676874):@(weight)}}];
    NSFont *font = [NSFont fontWithDescriptor:descriptor size:size];
    if (!font || ![font.familyName isEqual:family]) {
        NSFontWeight system = weight >= 650 ? NSFontWeightBold : weight >= 550 ? NSFontWeightSemibold : weight >= 450 ? NSFontWeightMedium : weight >= 350 ? NSFontWeightRegular : NSFontWeightLight;
        font = [NSFont systemFontOfSize:size weight:system];
    }
    cache[key] = font;
    return font;
}
NSFont *ShiroDisplayFont(CGFloat size, CGFloat weight) { return VariableFont(@"Unbounded", size, weight); }
NSFont *ShiroTextFont(CGFloat size, CGFloat weight) { return VariableFont(@"Onest", size, weight); }

#pragma mark - Themes

static NSColor *Hex(NSString *hex) {
    unsigned value = 0;
    [[NSScanner scannerWithString:[hex substringFromIndex:1]] scanHexInt:&value];
    return [NSColor colorWithSRGBRed:((value >> 16) & 255) / 255.0 green:((value >> 8) & 255) / 255.0 blue:(value & 255) / 255.0 alpha:1];
}

@interface ShiroTheme ()
@property(nonatomic, copy, readwrite) NSString *identifier, *number;
@property(nonatomic, strong, readwrite) NSColor *background, *ink, *muted, *popover, *popoverInk, *headBackground, *headInk, *headMuted;
@property(nonatomic, strong, readwrite) NSArray<NSColor *> *bandFills, *bandInks;
@property(nonatomic, readwrite) BOOL dark;
@end

@implementation ShiroTheme
+ (ShiroTheme *)themeFrom:(NSDictionary *)d {
    ShiroTheme *t = [[ShiroTheme alloc] init];
    t.identifier = d[@"id"]; t.number = d[@"name"]; t.dark = [d[@"dark"] boolValue];
    t.background = Hex(d[@"bg"]); t.ink = Hex(d[@"ink"]); t.muted = Hex(d[@"muted"]);
    t.popover = Hex(d[@"pop"]); t.popoverInk = Hex(d[@"popInk"]);
    NSDictionary *head = d[@"head"];
    t.headBackground = head ? Hex(head[@"bg"]) : t.background;
    t.headInk = head ? Hex(head[@"ink"]) : t.ink;
    t.headMuted = head ? Hex(head[@"muted"]) : t.muted;
    NSMutableArray *fills = [NSMutableArray array], *inks = [NSMutableArray array];
    for (NSArray *band in d[@"bands"]) { [fills addObject:Hex(band[0])]; [inks addObject:band.count > 1 ? Hex(band[1]) : t.ink]; }
    t.bandFills = fills; t.bandInks = inks;
    return t;
}
// Same palettes as the agreed HTML mock-up; order and numbers are part of the design.
+ (NSArray<ShiroTheme *> *)all {
    static NSArray *themes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *data = @[
            @{@"id":@"pastel", @"name":@"33", @"bg":@"#F5F3EF", @"ink":@"#1D1C21", @"muted":@"#8E8B93", @"pop":@"#FFFFFF", @"popInk":@"#1D1C21", @"bands":@[@[@"#F3E3AA"], @[@"#F3CDBB"], @[@"#EEC8D7"], @[@"#D9D0F0"], @[@"#C6DAEF"], @[@"#CBE4D6"]]},
            @{@"id":@"nature", @"name":@"42", @"bg":@"#ECE6D8", @"ink":@"#25231A", @"muted":@"#8A8470", @"pop":@"#FAF7EF", @"popInk":@"#25231A", @"bands":@[@[@"#DCCB96"], @[@"#CFA27A"], @[@"#B9C087"], @[@"#98A466"], @[@"#C8B188"]]},
            @{@"id":@"ice", @"name":@"71", @"bg":@"#EEF2F6", @"ink":@"#16202C", @"muted":@"#7C8897", @"pop":@"#FFFFFF", @"popInk":@"#16202C", @"bands":@[@[@"#DEE6EF"], @[@"#CDD9E6"], @[@"#BCCBDD"], @[@"#AABDD3"]]},
            @{@"id":@"juicy", @"name":@"67", @"bg":@"#F4F1EC", @"ink":@"#121214", @"muted":@"#8A8790", @"pop":@"#FFFFFF", @"popInk":@"#121214", @"bands":@[@[@"#FFC845"], @[@"#FF9469"], @[@"#F27DB9"], @[@"#A093F5"], @[@"#66A0F5"]]},
            @{@"id":@"shiro", @"name":@"00", @"bg":@"#0E0E10", @"ink":@"#F2F2F0", @"muted":@"#7C7C84", @"pop":@"#18181B", @"popInk":@"#F2F2F0", @"dark":@YES,
              @"head":@{@"bg":@"#C8102E", @"ink":@"#FFFFFF", @"muted":@"#FFB8C2"},
              @"bands":@[@[@"#F2F2F0", @"#0E0E10"], @[@"#C5C8CE", @"#0E0E10"], @[@"#1B1B1E", @"#F2F2F0"], @[@"#2C2D32", @"#F2F2F0"]]},
            @{@"id":@"mono", @"name":@"10", @"bg":@"#F2F2F0", @"ink":@"#111112", @"muted":@"#8B8B8E", @"pop":@"#FFFFFF", @"popInk":@"#111112", @"bands":@[@[@"#E6E6E3"], @[@"#DADAD6"], @[@"#CECEC9"], @[@"#C2C2BC"]]},
            @{@"id":@"night", @"name":@"90", @"bg":@"#131315", @"ink":@"#EDEDEF", @"muted":@"#7E7E86", @"pop":@"#232327", @"popInk":@"#EDEDEF", @"dark":@YES, @"bands":@[@[@"#1C1C1F"], @[@"#232326"], @[@"#2A2A2E"], @[@"#313136"]]},
            @{@"id":@"bsod", @"name":@"01", @"bg":@"#0A33B5", @"ink":@"#FFFFFF", @"muted":@"#9FB6FF", @"pop":@"#FFFFFF", @"popInk":@"#0A33B5", @"dark":@YES, @"bands":@[@[@"#0D3AC4"], @[@"#1244D1"], @[@"#184EDC"], @[@"#1F58E5"]]}
        ];
        NSMutableArray *list = [NSMutableArray array];
        for (NSDictionary *d in data) [list addObject:[ShiroTheme themeFrom:d]];
        themes = list;
    });
    return themes;
}
+ (ShiroTheme *)themeWithIdentifier:(NSString *)identifier {
    for (ShiroTheme *t in self.all) if ([t.identifier isEqual:identifier]) return t;
    return self.all.firstObject;
}
- (NSColor *)bandFillAt:(NSInteger)i { return self.bandFills[(NSUInteger)i % self.bandFills.count]; }
- (NSColor *)bandInkAt:(NSInteger)i { return self.bandInks[(NSUInteger)i % self.bandInks.count]; }
@end

#pragma mark - Drawing helpers

static void FillRect(NSRect r) { NSRectFillUsingOperation(r, NSCompositingOperationSourceOver); }
static NSColor *A(NSColor *color, CGFloat alpha) { return [color colorWithAlphaComponent:alpha]; }
static void FillCircle(NSRect r, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithOvalInRect:r] fill]; }
static void FillRound(NSRect r, CGFloat radius, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius] fill]; }
static NSPoint Center(NSRect r) { return NSMakePoint(NSMidX(r), NSMidY(r)); }

static NSSize TextSize(NSString *text, NSFont *font, CGFloat kern) {
    return [text sizeWithAttributes:@{NSFontAttributeName:font, NSKernAttributeName:@(kern)}];
}
// Draws text vertically centred on midY, starting at x (or ending at x when alignRight). Returns the width.
static CGFloat DrawText(NSString *text, CGFloat x, CGFloat midY, NSFont *font, NSColor *color, CGFloat kern, BOOL alignRight) {
    NSDictionary *style = @{NSFontAttributeName:font, NSForegroundColorAttributeName:color, NSKernAttributeName:@(kern)};
    NSSize size = [text sizeWithAttributes:style];
    CGFloat lineHeight = font.ascender - font.descender;
    [text drawAtPoint:NSMakePoint(alignRight ? x - size.width : x, round(midY - lineHeight / 2 - (size.height - lineHeight) / 2)) withAttributes:style];
    return size.width;
}
static void DrawTextInWidth(NSString *text, CGFloat x, CGFloat midY, CGFloat width, NSFont *font, NSColor *color, BOOL strike) {
    NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
    para.lineBreakMode = NSLineBreakByTruncatingTail;
    NSMutableDictionary *style = [@{NSFontAttributeName:font, NSForegroundColorAttributeName:color, NSParagraphStyleAttributeName:para} mutableCopy];
    if (strike) style[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
    CGFloat h = ceil(font.ascender - font.descender) + 2;
    [text drawWithRect:NSMakeRect(x, round(midY - h / 2), MAX(0, width), h) options:NSStringDrawingUsesLineFragmentOrigin attributes:style];
}

static NSBezierPath *Stroke(CGFloat width) {
    NSBezierPath *p = [NSBezierPath bezierPath];
    p.lineWidth = width; p.lineCapStyle = NSLineCapStyleRound; p.lineJoinStyle = NSLineJoinStyleRound;
    return p;
}
// Icons are drawn on a 24-unit grid centred in rect, like the mock-up's line icons; weight is in grid units, as SVG stroke-width.
static void DrawIcon(NSString *name, NSRect rect, CGFloat size, NSColor *color, CGFloat weight) {
    CGFloat s = size / 24.0, ox = NSMidX(rect) - size / 2, oy = NSMidY(rect) - size / 2;
    NSPoint (^P)(CGFloat, CGFloat) = ^NSPoint(CGFloat x, CGFloat y) { return NSMakePoint(ox + x * s, oy + y * s); };
    NSBezierPath *p = Stroke(weight * s);
    [color set];
    if ([name isEqual:@"plus"]) { [p moveToPoint:P(12,5)]; [p lineToPoint:P(12,19)]; [p moveToPoint:P(5,12)]; [p lineToPoint:P(19,12)]; }
    else if ([name isEqual:@"x"]) { [p moveToPoint:P(18,6)]; [p lineToPoint:P(6,18)]; [p moveToPoint:P(6,6)]; [p lineToPoint:P(18,18)]; }
    else if ([name isEqual:@"chevDown"]) { [p moveToPoint:P(6,9)]; [p lineToPoint:P(12,15)]; [p lineToPoint:P(18,9)]; }
    else if ([name isEqual:@"chevRight"]) { [p moveToPoint:P(9,6)]; [p lineToPoint:P(15,12)]; [p lineToPoint:P(9,18)]; }
    else if ([name isEqual:@"check"]) { [p moveToPoint:P(20,6)]; [p lineToPoint:P(9,17)]; [p lineToPoint:P(4,12)]; }
    else if ([name isEqual:@"arrow"]) { [p moveToPoint:P(5,12)]; [p lineToPoint:P(19,12)]; [p moveToPoint:P(13,6)]; [p lineToPoint:P(19,12)]; [p lineToPoint:P(13,18)]; }
    else if ([name isEqual:@"more"]) {
        CGFloat dots[3] = {5, 12, 19};
        for (int i = 0; i < 3; i++) { NSPoint c = P(dots[i], 12); [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(c.x - 1.6 * s, c.y - 1.6 * s, 3.2 * s, 3.2 * s)] fill]; }
        return;
    }
    else if ([name isEqual:@"reset"]) {
        [p moveToPoint:P(3,12)];
        [p appendBezierPathWithArcWithCenter:P(12,12) radius:9 * s startAngle:180 endAngle:-131.8 clockwise:YES];
        [p moveToPoint:P(3,3)]; [p lineToPoint:P(3,8)]; [p lineToPoint:P(8,8)];
    }
    else if ([name isEqual:@"doc"]) {
        [p moveToPoint:P(14,3)]; [p lineToPoint:P(6,3)]; [p lineToPoint:P(6,21)]; [p lineToPoint:P(18,21)]; [p lineToPoint:P(18,7)]; [p closePath];
        [p moveToPoint:P(14,3)]; [p lineToPoint:P(14,7)]; [p lineToPoint:P(18,7)];
        [p moveToPoint:P(9,12)]; [p lineToPoint:P(15,12)]; [p moveToPoint:P(9,16)]; [p lineToPoint:P(15,16)];
    }
    else if ([name isEqual:@"link"]) {
        // Two open links of a chain, as in the usual "link" line icon.
        NSBezierPath *a = Stroke(weight * s), *b = Stroke(weight * s);
        [a moveToPoint:P(10,13)];
        [a curveToPoint:P(15.5,13.5) controlPoint1:P(11.6,15.2) controlPoint2:P(14,15)];
        [a lineToPoint:P(19,10)];
        [a curveToPoint:P(14,5) controlPoint1:P(20.5,8.4) controlPoint2:P(15.6,3.5)];
        [a lineToPoint:P(12.5,6.5)];
        [b moveToPoint:P(14,11)];
        [b curveToPoint:P(8.5,10.5) controlPoint1:P(12.4,8.8) controlPoint2:P(10,9)];
        [b lineToPoint:P(5,14)];
        [b curveToPoint:P(10,19) controlPoint1:P(3.5,15.6) controlPoint2:P(8.4,20.5)];
        [b lineToPoint:P(11.5,17.5)];
        [a stroke]; [b stroke];
        return;
    }
    else if ([name isEqual:@"sliders"]) {
        CGFloat lines[9][4] = {{4,21,4,14},{4,10,4,3},{12,21,12,12},{12,8,12,3},{20,21,20,16},{20,12,20,3},{1,14,7,14},{9,8,15,8},{17,16,23,16}};
        for (int i = 0; i < 9; i++) { [p moveToPoint:P(lines[i][0], lines[i][1])]; [p lineToPoint:P(lines[i][2], lines[i][3])]; }
    }
    [p stroke];
}
static void DrawPlay(NSRect r, NSColor *c) {
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p moveToPoint:NSMakePoint(NSMinX(r) + r.size.width * .21, NSMinY(r) + r.size.height * .10)];
    [p lineToPoint:NSMakePoint(NSMinX(r) + r.size.width * .21, NSMinY(r) + r.size.height * .90)];
    [p lineToPoint:NSMakePoint(NSMinX(r) + r.size.width * .90, NSMidY(r))];
    [p closePath]; [c setFill]; [p fill];
}
static void DrawPause(NSRect r, NSColor *c) {
    CGFloat w = r.size.width * .21, h = r.size.height * .75, y = NSMidY(r) - h / 2;
    [c setFill];
    FillRect(NSMakeRect(NSMinX(r) + r.size.width * .21, y, w, h));
    FillRect(NSMakeRect(NSMinX(r) + r.size.width * .58, y, w, h));
}

#pragma mark - Hit regions and accessibility

@interface ShiroHit : NSObject
@property(nonatomic) NSRect rect;
@property(nonatomic, copy) NSString *action, *ident, *label;
@end
@implementation ShiroHit @end

@interface ShiroAXButton : NSAccessibilityElement
@property(nonatomic, copy) void (^press)(void);
@end
@implementation ShiroAXButton
- (BOOL)accessibilityPerformPress { if (self.press) self.press(); return YES; }
@end

@interface ShiroEditor : NSTextField @end
@implementation ShiroEditor
- (BOOL)acceptsFirstResponder { return YES; }
@end

#pragma mark - Panel

const CGFloat ShiroPanelWidth = 560;
// S matches the agreed mock-up as it looks on screen; M and L are for larger displays or eyesight.
NSArray<NSNumber *> *ShiroScaleSteps(void) { return @[@0.72, @0.86, @1.0]; }

static const CGFloat kRadius = 28, kBarH = 46, kHeadH = 154, kTheadH = 44, kSecHeadH = 46, kRowH = 40, kTitleX = 84;

// One line of the list after layout, in list coordinates (0 is the top of the "Tasks" heading).
@interface ShiroItem : NSObject
@property(nonatomic, copy) NSString *kind;        // sectionForm, header, taskForm, row, empty, doneHeader, doneRow
@property(nonatomic, copy) NSString *sectionID, *taskID;
@property(nonatomic) NSInteger band;               // colour index; -1 is the done list
@property(nonatomic) CGFloat y, h, titleH;
@end
@implementation ShiroItem @end

// A coloured block: a section, or the done list when sectionID is nil.
@interface ShiroBlock : NSObject
@property(nonatomic, copy) NSString *sectionID;
@property(nonatomic) NSInteger band;
@property(nonatomic) CGFloat top, bottom;
@property(nonatomic) BOOL collapsed;
@end
@implementation ShiroBlock @end

@interface ShiroDrop : NSObject
@property(nonatomic, copy) NSString *sectionID, *beforeID;   // sectionID nil = done list
@property(nonatomic) CGFloat lineY;                         // list coordinates; NAN highlights the whole block
@end
@implementation ShiroDrop @end

@interface ShiroPanelView ()
@property(nonatomic) NSMutableArray<ShiroHit *> *hits;
@property(nonatomic, copy) NSString *hoverKey;
@property(nonatomic) CGFloat scrollY;
@property(nonatomic, strong) NSArray<ShiroItem *> *items;
@property(nonatomic, strong) NSArray<ShiroBlock *> *blocks;
@property(nonatomic) CGFloat layoutHeight;
@property(nonatomic, copy) NSString *editKind, *editTarget;   // task / section / renameTask / renameSection / link
@property(nonatomic, strong) ShiroEditor *editor;
@property(nonatomic) NSRect editorRect;
@property(nonatomic) BOOL finishingEdit;
@property(nonatomic, copy) NSString *pressAction, *pressIdent;
@property(nonatomic) NSPoint pressPoint;
@property(nonatomic, copy) NSString *dragSection, *dragTask;
@property(nonatomic) BOOL dragging;
@property(nonatomic) NSInteger dropGap;
@property(nonatomic, strong) ShiroDrop *drop;
@property(nonatomic, copy) NSString *toast;
@property(nonatomic) NSTimeInterval toastUntil;
@property(nonatomic, strong) NSArray *axElements;
@end

@implementation ShiroPanelView
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _hits = [NSMutableArray array];
        _scope = @"global";
        _dropGap = -1;
        _theme = ShiroTheme.all.firstObject;
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
    }
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (BOOL)isFlipped { return YES; }
// Layout is written for a 560-point-wide window and drawn scaled by uiScale.
- (CGFloat)k { return self.uiScale > 0 ? self.uiScale : 1; }
- (NSSize)logicalSize { return NSMakeSize(self.bounds.size.width / self.k, self.bounds.size.height / self.k); }
- (NSRect)toView:(NSRect)r { CGFloat k = self.k; return NSMakeRect(r.origin.x * k, r.origin.y * k, r.size.width * k, r.size.height * k); }
- (NSPoint)logicalPoint:(NSEvent *)event { NSPoint p = [self convertPoint:event.locationInWindow fromView:nil]; return NSMakePoint(p.x / self.k, p.y / self.k); }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)isOpaque { return NO; }
- (void)viewDidMoveToWindow {
    [NSNotificationCenter.defaultCenter removeObserver:self name:NSWindowDidResignKeyNotification object:nil];
    if (self.window) [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowResigned:) name:NSWindowDidResignKeyNotification object:self.window];
}
// Clicking outside the window keeps what was typed.
- (void)windowResigned:(NSNotification *)note { if (self.editKind) [self commitEditContinuing:NO]; }

- (void)setTheme:(ShiroTheme *)theme { _theme = theme; [self updateEditorStyle]; self.needsDisplay = YES; }
- (BOOL)editTargetExists {
    NSString *kind = self.editKind;
    if (!kind || [kind isEqual:@"section"]) return YES;
    if ([kind isEqual:@"fileTask"]) return self.fileName != nil;
    if ([kind isEqual:@"task"] || [kind isEqual:@"renameSection"]) return [self.store sectionWithID:self.editTarget] != nil;
    return [self.store taskWithID:self.editTarget] != nil;
}
- (void)reloadContent {
    if (self.editKind && ![self editTargetExists]) [self endEditing];
    [self clampScroll];
    self.needsDisplay = YES;
    [self.delegate panelContentHeightChanged];
}
- (void)refreshTimer { [self setNeedsDisplayInRect:NSMakeRect(0, 0, self.bounds.size.width, kHeadH * self.k)]; if ([self.scope isEqual:@"task"]) self.needsDisplay = YES; }
- (void)showToast:(NSString *)text {
    self.toast = text; self.toastUntil = NSDate.date.timeIntervalSince1970 + 2.2; self.needsDisplay = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ self.needsDisplay = YES; });
}
- (NSString *)timeText:(double)seconds {
    NSInteger s = (NSInteger)ceil(fmax(0, seconds) - 0.0001);
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(s / 60), (long)(s % 60)];
}

#pragma mark Layout

- (CGFloat)W { return ShiroPanelWidth; }
- (NSFont *)titleFontSelected:(BOOL)selected { return ShiroTextFont(15, selected ? 600 : 400); }
- (CGFloat)heightOf:(NSString *)text font:(NSFont *)font width:(CGFloat)width {
    if (!text.length) text = @"M";
    NSRect r = [text boundingRectWithSize:NSMakeSize(MAX(20, width), CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:font}];
    return ceil(r.size.height);
}
- (CGFloat)taskTimeWidth { return [self.scope isEqual:@"task"] ? TextSize(@"00:00", ShiroDisplayFont(12, 400), 0).width + 10 : 0; }
- (CGFloat)titleWidthDone:(BOOL)done {
    CGFloat right = self.W - 10 - 30 - 8;
    if (done) right -= 90; else right -= self.taskTimeWidth;
    return right - kTitleX;
}
- (CGFloat)fileTitleWidth { return self.W - 10 - 30 - 8 - kTitleX; }
- (CGFloat)editorWidthFor:(NSString *)kind {
    if ([kind isEqual:@"section"]) return self.W - 18 - 72 - 18;
    if ([kind isEqual:@"renameSection"]) return self.W - 8 - 72 - 50;
    return self.W - 10 - 72 - kTitleX;
}
- (NSFont *)editorFont { return ShiroTextFont(15, [self.editKind isEqual:@"renameSection"] ? 600 : 400); }
- (CGFloat)formHeight {
    CGFloat textH = [self heightOf:self.editor.stringValue font:self.editorFont width:[self editorWidthFor:self.editKind] - 4];
    return MAX(kRowH, textH + 18);
}
- (CGFloat)rowHeightFor:(NSDictionary *)task titleHeight:(CGFloat *)titleH {
    BOOL done = [task[@"done"] boolValue], selected = [self.store.activeTaskID isEqual:task[@"id"]];
    CGFloat h = [self heightOf:task[@"title"] font:[self titleFontSelected:selected] width:[self titleWidthDone:done]];
    if (titleH) *titleH = h;
    return MAX(kRowH, h + 20) + ([task[@"link"] length] ? 18 : 0);
}
- (void)layout {
    NSMutableArray *items = [NSMutableArray array], *blocks = [NSMutableArray array];
    ShiroItem *(^add)(NSString *, NSString *, NSString *, NSInteger, CGFloat, CGFloat) = ^ShiroItem *(NSString *kind, NSString *sid, NSString *tid, NSInteger band, CGFloat y, CGFloat h) {
        ShiroItem *item = [[ShiroItem alloc] init];
        item.kind = kind; item.sectionID = sid; item.taskID = tid; item.band = band; item.y = y; item.h = h;
        [items addObject:item]; return item;
    };
    __block CGFloat y = kTheadH;
    if ([self.editKind isEqual:@"section"]) { add(@"sectionForm", nil, nil, 0, y, self.formHeight); y += self.formHeight; }
    void (^addFileBlock)(void) = ^{
        if (!self.fileName) return;
        ShiroBlock *block = [[ShiroBlock alloc] init];
        block.sectionID = @"file"; block.band = -2; block.top = y; block.collapsed = self.fileCollapsed;
        add(@"fileHeader", @"file", nil, -2, y, kSecHeadH); y += kSecHeadH;
        if ([self.editKind isEqual:@"fileTask"]) { add(@"taskForm", @"file", nil, -2, y, self.formHeight); y += self.formHeight; }
        if (!block.collapsed) {
            if (self.fileMissing || !self.fileTasks.count) { add(@"fileEmpty", @"file", nil, -2, y, kRowH); y += kRowH; }
            NSString *lastSection = nil;
            for (NSUInteger i = 0; i < self.fileTasks.count; i++) {
                ShiroFileTask *task = self.fileTasks[i];
                if (task.section.length && ![task.section isEqual:lastSection]) { add(@"fileSection", @"file", nil, -2, y, 30); y += 30; }
                lastSection = task.section;
                CGFloat h = [self heightOf:task.title font:[self titleFontSelected:[task.title isEqual:self.activeFileTitle] && !task.done] width:self.fileTitleWidth];
                ShiroItem *row = add(@"fileRow", @"file", [NSString stringWithFormat:@"file:%lu", (unsigned long)i], -2, y, MAX(kRowH, h + 20) + (task.link.length ? 18 : 0));
                row.titleH = h; y += row.h;
            }
        }
        y += 4; block.bottom = y; [blocks addObject:block];
    };
    NSArray *sections = self.store.sections;
    NSUInteger fileAt = (NSUInteger)MAX(0, MIN(self.fileIndex, (NSInteger)sections.count));
    for (NSUInteger i = 0; i < sections.count; i++) {
        if (i == fileAt) addFileBlock();
        NSDictionary *section = sections[i];
        NSString *sid = section[@"id"];
        ShiroBlock *block = [[ShiroBlock alloc] init];
        block.sectionID = sid; block.band = (NSInteger)i; block.top = y; block.collapsed = [section[@"collapsed"] boolValue];
        add(@"header", sid, nil, (NSInteger)i, y, kSecHeadH); y += kSecHeadH;
        if ([self.editKind isEqual:@"task"] && [self.editTarget isEqual:sid]) { add(@"taskForm", sid, nil, (NSInteger)i, y, self.formHeight); y += self.formHeight; }
        if (!block.collapsed) {
            NSArray *tasks = [self.store openTasksInSectionID:sid];
            for (NSDictionary *task in tasks) {
                BOOL editing = ([self.editKind isEqual:@"renameTask"] || [self.editKind isEqual:@"link"]) && [self.editTarget isEqual:task[@"id"]];
                CGFloat titleH = 0, h = editing ? self.formHeight : [self rowHeightFor:task titleHeight:&titleH];
                ShiroItem *row = add(editing ? @"taskForm" : @"row", sid, task[@"id"], (NSInteger)i, y, h);
                row.titleH = titleH; y += h;
            }
            if (!tasks.count && !([self.editKind isEqual:@"task"] && [self.editTarget isEqual:sid])) { add(@"empty", sid, nil, (NSInteger)i, y, kRowH); y += kRowH; }
        }
        y += 4; block.bottom = y; [blocks addObject:block];
    }
    if (fileAt >= sections.count) addFileBlock();
    NSArray *done = self.store.doneTasks;
    if (done.count || (self.dragging && self.dragTask && ![self.dragTask hasPrefix:@"file:"])) {
        ShiroBlock *block = [[ShiroBlock alloc] init];
        block.band = -1; block.top = y; block.collapsed = self.store.doneCollapsed;
        add(@"doneHeader", nil, nil, -1, y, kSecHeadH); y += kSecHeadH;
        if (!block.collapsed) for (NSDictionary *task in done) {
            CGFloat titleH = 0, h = [self rowHeightFor:task titleHeight:&titleH];
            ShiroItem *row = add(@"doneRow", task[@"sectionID"], task[@"id"], -1, y, h);
            row.titleH = titleH; y += h;
        }
        y += 4; block.bottom = y; [blocks addObject:block];
    }
    y += 4;
    self.items = items; self.blocks = blocks; self.layoutHeight = y;
}
- (CGFloat)contentListHeight { [self layout]; return self.layoutHeight; }
- (CGFloat)preferredHeight { return ceil((kHeadH + [self contentListHeight]) * self.k); }
- (CGFloat)visibleListHeight { return MAX(0, self.logicalSize.height - kHeadH); }
- (void)clampScroll { self.scrollY = MAX(0, MIN(self.scrollY, [self contentListHeight] - [self visibleListHeight])); }
- (void)scrollWheel:(NSEvent *)event {
    CGFloat before = self.scrollY;
    self.scrollY -= (event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 12) / self.k;
    [self clampScroll];
    if (self.scrollY != before) self.needsDisplay = YES;
}

- (void)addHit:(NSRect)rect action:(NSString *)action ident:(NSString *)ident label:(NSString *)label {
    ShiroHit *hit = [[ShiroHit alloc] init];
    hit.rect = rect; hit.action = action; hit.ident = ident; hit.label = label;
    [self.hits addObject:hit];
}
- (NSString *)keyFor:(NSString *)action ident:(NSString *)ident { return [NSString stringWithFormat:@"%@|%@", action, ident ?: @""]; }
- (BOOL)hovered:(NSString *)action ident:(NSString *)ident { return [self.hoverKey isEqual:[self keyFor:action ident:ident]]; }

#pragma mark Drawing

// Bands: 0… sections, -1 the done list, -2 the connected file.
- (NSColor *)fillForBand:(NSInteger)band {
    if (band == -2) return self.theme.popover;
    return band < 0 ? [self.theme.background blendedColorWithFraction:.06 ofColor:self.theme.ink] : [self.theme bandFillAt:band];
}
- (NSColor *)inkForBand:(NSInteger)band { return band == -2 ? self.theme.popoverInk : band < 0 ? self.theme.ink : [self.theme bandInkAt:band]; }

- (void)drawRect:(NSRect)dirty {
    [self.hits removeAllObjects];
    CGFloat W = self.logicalSize.width, H = self.logicalSize.height;
    NSRect logical = NSMakeRect(0, 0, W, H);
    [NSGraphicsContext saveGraphicsState];
    CGContextScaleCTM(NSGraphicsContext.currentContext.CGContext, self.k, self.k);
    NSBezierPath *shape = [NSBezierPath bezierPathWithRoundedRect:logical xRadius:kRadius yRadius:kRadius];
    [shape addClip];
    [self.theme.background setFill]; FillRect(logical);
    [self drawHeadWidth:W];
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(NSMakeRect(0, kHeadH, W, H - kHeadH));
    [self drawListTop:kHeadH - self.scrollY height:H];
    [NSGraphicsContext restoreGraphicsState];
    if (self.toast && NSDate.date.timeIntervalSince1970 < self.toastUntil) {
        NSFont *font = ShiroTextFont(14, 500);
        NSSize size = TextSize(self.toast, font, 0);
        NSRect pill = NSMakeRect(round((W - size.width) / 2) - 16, H - 52, size.width + 32, 36);
        FillRound(pill, 18, self.theme.ink);
        DrawText(self.toast, NSMinX(pill) + 16, NSMidY(pill), font, self.theme.background, 0, NO);
    }
    [NSGraphicsContext restoreGraphicsState];
    [self rebuildAccessibility];
}

- (void)drawHeadWidth:(CGFloat)W {
    ShiroTheme *t = self.theme;
    NSColor *ink = t.headInk, *bg = t.headBackground;
    [bg setFill]; FillRect(NSMakeRect(0, 0, W, kHeadH));

    DrawText(@"SHIRO", 18, kBarH / 2 + 1, ShiroDisplayFont(14, 400), ink, 2.3, NO);
    NSRect close = NSMakeRect(W - 10 - 32, 7, 32, 32), settings = NSMakeRect(NSMinX(close) - 34, 7, 32, 32);
    for (NSArray *button in @[@[@"settings", [NSValue valueWithRect:settings], @"sliders", ShiroL(@"settings")], @[@"close", [NSValue valueWithRect:close], @"x", ShiroL(@"hide")]]) {
        NSRect r = [button[1] rectValue];
        if ([self hovered:button[0] ident:nil]) FillCircle(r, A(ink, .12));
        DrawIcon(button[2], r, 16, [self hovered:button[0] ident:nil] ? ink : t.headMuted, 2);
        [self addHit:r action:button[0] ident:nil label:button[3]];
    }

    // Ruler: one tick per minute, bigger every five; the black mark is "now".
    double total = [self.timer durationOfPhase:self.timer.phase], left = [self.timer remainingAt:self.now];
    double frac = total > 0 ? fmin(1, fmax(0, (total - left) / total)) : 0;
    NSInteger minutes = MAX(1, MIN(60, (NSInteger)llround(total / 60)));
    CGFloat rx = 20, rw = W - 40, top = 48;
    FillRound(NSMakeRect(rx, top + 4, rw * frac, 18), 3, A(ink, .08));
    for (NSInteger i = 0; i <= minutes; i++) {
        BOOL major = i % 5 == 0;
        CGFloat x = round(rx + rw * i / minutes) - (i == minutes ? 1 : 0);
        [A(ink, major ? .46 : .24) setFill];
        FillRect(NSMakeRect(x, top + 22 - (major ? 16 : 9), 1, major ? 16 : 9));
    }
    FillRound(NSMakeRect(rx + rw * frac - 1, top + 1, 3, 24), 1.5, ink);

    CGFloat mid = 112;
    NSRect play = NSMakeRect(18, mid - 17, 30, 34);
    if (self.timer.running) DrawPause(play, ink); else DrawPlay(play, ink);
    CGFloat timeW = DrawText([self timeText:left], 64, mid, ShiroDisplayFont(50, 300), ink, 0.5, NO);
    [self addHit:NSMakeRect(10, mid - 26, 64 + timeW, 52) action:@"toggle" ident:nil label:ShiroMainLabel(self.timer, self.now)];
    [[NSString stringWithFormat:@"/%ld", (long)minutes] drawAtPoint:NSMakePoint(64 + timeW + 6, mid - 27) withAttributes:@{NSFontAttributeName:ShiroTextFont(13, 500), NSForegroundColorAttributeName:t.headMuted}];

    NSRect reset = NSMakeRect(W - 18 - 46, mid - 23, 46, 46);
    if (self.timer.running) {
        NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(reset, -4.5, -4.5)];
        ring.lineWidth = 1; [A(ink, .3) setStroke]; [ring stroke];
    }
    FillCircle(reset, [self hovered:@"reset" ident:nil] ? A(ink, .85) : ink);
    DrawIcon(@"reset", reset, 18, bg, 2);
    [self addHit:reset action:@"reset" ident:nil label:ShiroL(@"reset")];

    NSFont *modeFont = ShiroTextFont(14, 600);
    CGFloat x = NSMinX(reset) - 16;
    for (NSString *phase in @[@"break", @"work"]) {
        NSString *label = ShiroL([phase isEqual:@"work"] ? @"focus" : @"break");
        BOOL active = [self.timer.phase isEqual:phase];
        NSColor *color = active ? ink : A(ink, [self hovered:@"phase" ident:phase] ? .6 : .3);
        CGFloat w = DrawText(label, x, mid, modeFont, color, 0, YES);
        [self addHit:NSMakeRect(x - w - 6, mid - 16, w + 12, 32) action:@"phase" ident:phase label:label];
        x -= w + 14;
    }
}

- (void)drawRoundButton:(NSString *)icon rect:(NSRect)r action:(NSString *)action ident:(NSString *)ident label:(NSString *)label ink:(NSColor *)ink base:(CGFloat)base {
    CGFloat alpha = [self hovered:action ident:ident] ? MAX(.12, base * 2) : base;
    if (alpha > 0) FillCircle(r, A(ink, alpha));
    DrawIcon(icon, r, 16, ink, 2);
    [self addHit:r action:action ident:ident label:label];
}

// Inline form: optional marker on the left, the text field, and ✓ / × on the right.
- (void)drawFormRow:(NSRect)row inputX:(CGFloat)inputX marker:(NSString *)marker ink:(NSColor *)ink fill:(NSColor *)fill top:(CGFloat)top {
    NSString *kind = self.editKind;
    NSString *okLabel = ShiroL([kind isEqual:@"task"] || [kind isEqual:@"fileTask"] ? @"add" : [kind isEqual:@"section"] ? @"createSection" : @"save");
    CGFloat firstMid = NSMinY(row) + 20;
    NSRect cancel = NSMakeRect(NSMaxX(row) - 28, firstMid - 14, 28, 28), ok = NSMakeRect(NSMinX(cancel) - 34, NSMinY(cancel), 28, 28);
    FillCircle(ok, [self hovered:@"formOK" ident:nil] ? A(ink, .85) : ink);
    DrawIcon(@"check", ok, 15, fill, 3);
    if ([self hovered:@"formCancel" ident:nil]) FillCircle(cancel, A(ink, .1));
    DrawIcon(@"x", cancel, 15, ink, 2.4);
    [self addHit:ok action:@"formOK" ident:nil label:okLabel];
    [self addHit:cancel action:@"formCancel" ident:nil label:ShiroL(@"cancel")];
    NSRect marker_ = NSMakeRect(54, firstMid - 10, 20, 20);
    if ([marker isEqual:@"dash"]) {
        NSBezierPath *dash = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(marker_, 1, 1)];
        CGFloat pattern[2] = {3, 3}; [dash setLineDash:pattern count:2 phase:0]; dash.lineWidth = 2;
        [A(ink, .4) setStroke]; [dash stroke];
    } else if ([marker isEqual:@"link"]) DrawIcon(@"link", marker_, 16, A(ink, .7), 2);
    CGFloat width = [self editorWidthFor:kind];
    CGFloat textH = MAX(22, [self heightOf:self.editor.stringValue font:self.editorFont width:width - 4]);
    NSRect input = NSMakeRect(inputX, NSMinY(row) + 9, width, textH);
    [(self.editor.currentEditor ? ink : A(ink, .28)) setFill];
    FillRect(NSMakeRect(NSMinX(input), NSMaxY(input) + 2, input.size.width, 1.5));
    self.editorRect = input;
}

- (NSString *)linkLabel:(NSString *)link {
    // Readable label: decoded, without the query part (?node-id=…).
    NSString *text = [link componentsSeparatedByString:@"?"].firstObject;
    text = text.stringByRemovingPercentEncoding ?: text;
    for (NSString *prefix in @[@"https://", @"http://", @"www."]) if ([text.lowercaseString hasPrefix:prefix]) text = [text substringFromIndex:prefix.length];
    return text;
}

- (void)drawListTop:(CGFloat)top height:(CGFloat)H {
    ShiroTheme *t = self.theme;
    CGFloat W = self.W;
    [self layout];
    BOOL editorPlaced = NO;

    // Heading
    CGFloat mid = top + 24;
    CGFloat w = DrawText(ShiroL(@"tasks"), 18, mid, ShiroTextFont(15, 600), t.ink, 0, NO);
    NSInteger open = 0; for (NSDictionary *task in self.store.tasks) if (![task[@"done"] boolValue]) open++;
    DrawText(ShiroActiveCount(open), 18 + w + 8, mid, ShiroTextFont(13, 400), t.muted, 0, NO);
    NSFont *addFont = ShiroTextFont(14, 500);
    NSSize addSize = TextSize(ShiroL(@"addSection"), addFont, 0);
    NSRect add = NSMakeRect(W - 18 - addSize.width - 20, mid - 14, addSize.width + 20, 28);
    BOOL addHover = [self hovered:@"addSection" ident:nil];
    if (addHover) FillRound(add, 14, A(t.ink, .07));
    DrawText(ShiroL(@"addSection"), NSMinX(add) + 10, mid, addFont, addHover ? t.ink : t.muted, 0, NO);
    [self addHit:add action:@"addSection" ident:nil label:ShiroL(@"createSection")];

    // Block fills; the last one runs to the bottom edge so the rounded corner is filled.
    for (NSUInteger b = 0; b < self.blocks.count; b++) {
        ShiroBlock *block = self.blocks[b];
        CGFloat bottom = b + 1 == self.blocks.count ? MAX(top + block.bottom, H) + 4 : top + block.bottom;
        [[self fillForBand:block.band] setFill]; FillRect(NSMakeRect(0, top + block.top, W, bottom - top - block.top));
        BOOL target = self.dragging && self.dragTask && self.drop && isnan(self.drop.lineY) && ((block.sectionID == nil && self.drop.sectionID == nil) || [block.sectionID isEqual:self.drop.sectionID]);
        if (target) { [A([self inkForBand:block.band], .10) setFill]; FillRect(NSMakeRect(0, top + block.top, W, (b + 1 == self.blocks.count ? bottom : top + block.bottom) - top - block.top)); }
    }

    CGContextRef cg = NSGraphicsContext.currentContext.CGContext;
    for (ShiroItem *item in self.items) {
        CGFloat y = top + item.y;
        if (y > H + 10 || y + item.h < kHeadH - 10) continue;
        NSColor *ink = [self inkForBand:item.band], *fill = [self fillForBand:item.band];
        BOOL faded = self.dragging && (([item.kind isEqual:@"header"] && [self.dragSection isEqual:item.sectionID]) ||
                                       ((self.dragSection && [self.dragSection isEqual:item.sectionID] && item.band != -1)) ||
                                       (item.taskID && [self.dragTask isEqual:item.taskID]));
        if (faded) { CGContextSaveGState(cg); CGContextSetAlpha(cg, .35); CGContextBeginTransparencyLayer(cg, NULL); }
        NSDictionary *section = [self.store sectionWithID:item.sectionID];
        NSDictionary *task = [self.store taskWithID:item.taskID];

        if ([item.kind isEqual:@"sectionForm"]) {
            [self drawFormRow:NSMakeRect(18, y, W - 36, item.h) inputX:18 marker:nil ink:t.ink fill:t.background top:top];
            editorPlaced = YES;
        }
        else if ([item.kind isEqual:@"fileHeader"]) {
            CGFloat hm = y + 23;
            NSRect chev = NSMakeRect(W - 8 - 30, hm - 15, 30, 30), plus = NSMakeRect(NSMinX(chev) - 33, NSMinY(chev), 30, 30);
            FillCircle(NSMakeRect(14, hm - 13, 26, 26), A(ink, .08));
            DrawIcon(@"doc", NSMakeRect(14, hm - 13, 26, 26), 15, A(ink, .75), 2);
            NSInteger open = 0; for (ShiroFileTask *ft in self.fileTasks) if (!ft.done) open++;
            NSFont *nameFont = ShiroTextFont(15, 600);
            CGFloat nameW = MIN(TextSize(self.fileName, nameFont, 0).width, NSMinX(plus) - 12 - 50 - 40);
            DrawTextInWidth(self.fileName, 50, hm, nameW + 2, nameFont, ink, NO);
            if (!self.fileMissing) DrawText([NSString stringWithFormat:@"%ld", (long)open], 50 + nameW + 10, hm, ShiroTextFont(12, 600), A(ink, .55), 0.4, NO);
            [self addHit:NSMakeRect(0, y, NSMinX(plus) - 4, kSecHeadH) action:@"fileHeader" ident:nil label:self.fileName];
            [self drawRoundButton:@"plus" rect:plus action:@"fileAdd" ident:nil label:ShiroL(@"addToFile") ink:ink base:.07];
            [self drawRoundButton:self.fileCollapsed ? @"chevRight" : @"chevDown" rect:chev action:@"fileToggle" ident:nil label:ShiroL(self.fileCollapsed ? @"expand" : @"collapse") ink:ink base:.07];
        }
        else if ([item.kind isEqual:@"fileSection"]) {
            NSString *name = self.fileTasks[(NSUInteger)[self fileIndexAfter:item]].section;
            DrawTextInWidth(name.uppercaseString, 54, y + 17, W - 54 - 20, ShiroTextFont(11, 600), A(ink, .45), NO);
        }
        else if ([item.kind isEqual:@"fileEmpty"]) {
            [A(ink, .10) setFill]; FillRect(NSMakeRect(52, y, W - 62, 1));
            DrawText(ShiroL(self.fileMissing ? @"fileMissing" : @"fileEmpty"), 54, y + kRowH / 2, ShiroTextFont(14, 400), A(ink, .55), 0, NO);
        }
        else if ([item.kind isEqual:@"fileRow"]) {
            NSInteger index = [[item.taskID substringFromIndex:5] integerValue];
            ShiroFileTask *ft = self.fileTasks[(NSUInteger)index];
            CGFloat firstMid = y + 20;
            BOOL selected = !ft.done && [ft.title isEqual:self.activeFileTitle];
            [self addHit:NSMakeRect(0, y, W - 10 - 30, item.h) action:@"fileRow" ident:item.taskID label:ft.title];
            if (selected) { NSRect go = NSMakeRect(14, firstMid - 12, 24, 24); FillCircle(go, ink); DrawIcon(@"arrow", go, 14, fill, 2.6); }
            if ([self hovered:@"fileRow" ident:item.taskID] || [self hovered:@"import" ident:item.taskID]) { [A(ink, .04) setFill]; FillRect(NSMakeRect(52, y, W - 62, item.h)); }
            [A(ink, .10) setFill]; FillRect(NSMakeRect(52, y, W - 62, 1));
            // The circle marks the task done right in the file ("[ ]" ↔ "[x]").
            NSRect mark = NSMakeRect(54, firstMid - 10, 20, 20);
            if (ft.done) { FillCircle(mark, A(ink, .5)); DrawIcon(@"check", mark, 12, fill, 3); }
            else { NSBezierPath *c = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(mark, 1, 1)]; c.lineWidth = 2; [A(ink, [self hovered:@"fileCheck" ident:item.taskID] ? 1 : .75) setStroke]; [c stroke]; }
            [self addHit:NSInsetRect(mark, -6, -8) action:@"fileCheck" ident:item.taskID label:ShiroL(ft.done ? @"reopen" : @"markDone")];
            BOOL inShiro = NO;
            for (NSDictionary *own in self.store.tasks) if ([own[@"title"] isEqual:ft.title]) { inShiro = YES; break; }
            NSRect button = NSMakeRect(W - 10 - 30, firstMid - 15, 30, 30);
            if (inShiro) DrawIcon(@"check", button, 14, A(ink, .4), 2);
            else [self drawRoundButton:@"plus" rect:button action:@"import" ident:item.taskID label:ShiroL(@"importToShiro") ink:ink base:0];
            NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
            para.lineBreakMode = NSLineBreakByWordWrapping;
            NSMutableDictionary *style = [@{NSFontAttributeName:[self titleFontSelected:selected], NSForegroundColorAttributeName:selected ? ink : A(ink, ft.done || inShiro ? .5 : .9), NSParagraphStyleAttributeName:para} mutableCopy];
            if (ft.done) style[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
            [ft.title drawWithRect:NSMakeRect(kTitleX, y + 10, self.fileTitleWidth, item.titleH + 2) options:NSStringDrawingUsesLineFragmentOrigin attributes:style];
            if (ft.link.length) {
                CGFloat ly = y + 10 + item.titleH + 9;
                BOOL hover = [self hovered:@"fileLink" ident:item.taskID];
                NSString *label = [ft.link hasPrefix:@"obsidian://"] ? @"Obsidian" : [self linkLabel:ft.link];
                DrawIcon(@"link", NSMakeRect(kTitleX - 1, ly - 7, 14, 14), 13, A(ink, hover ? .9 : .5), 2);
                NSFont *f = ShiroTextFont(12, 500);
                CGFloat lw = MIN(TextSize(label, f, 0).width, self.fileTitleWidth - 20);
                DrawTextInWidth(label, kTitleX + 18, ly, lw + 2, f, A(ink, hover ? .9 : .5), NO);
                [self addHit:NSMakeRect(kTitleX - 4, ly - 10, lw + 26, 20) action:@"fileLink" ident:item.taskID label:[NSString stringWithFormat:@"%@: %@", ShiroL(@"openLink"), label]];
            }
        }
        else if ([item.kind isEqual:@"header"] || [item.kind isEqual:@"doneHeader"]) {
            BOOL doneList = [item.kind isEqual:@"doneHeader"];
            CGFloat hm = y + 23;
            NSRect chev = NSMakeRect(W - 8 - 30, hm - 15, 30, 30), more = NSMakeRect(NSMinX(chev) - 33, NSMinY(chev), 30, 30), plus = NSMakeRect(NSMinX(more) - 33, NSMinY(chev), 30, 30);
            if (doneList) {
                NSInteger count = (NSInteger)self.store.doneTasks.count;
                CGFloat nameW = DrawText(ShiroL(@"doneList"), 50, hm, ShiroTextFont(15, 600), ink, 0, NO);
                DrawText([NSString stringWithFormat:@"%ld", (long)count], 50 + nameW + 10, hm, ShiroTextFont(12, 600), A(ink, .55), 0.4, NO);
                FillCircle(NSMakeRect(14, hm - 13, 26, 26), A(ink, .10));
                DrawIcon(@"check", NSMakeRect(14, hm - 13, 26, 26), 13, A(ink, .7), 2.4);
                [self addHit:NSMakeRect(0, y, NSMinX(more) - 4, kSecHeadH) action:@"doneHeader" ident:nil label:ShiroL(@"doneList")];
                BOOL collapsed = self.store.doneCollapsed;
                if (!collapsed && count) {
                    NSFont *f = ShiroTextFont(13, 500);
                    NSSize size = TextSize(ShiroL(@"clearDone"), f, 0);
                    NSRect clear = NSMakeRect(NSMinX(chev) - 8 - size.width - 20, hm - 14, size.width + 20, 28);
                    if ([self hovered:@"clearDone" ident:nil]) FillRound(clear, 14, A(ink, .09));
                    DrawText(ShiroL(@"clearDone"), NSMinX(clear) + 10, hm, f, A(ink, .7), 0, NO);
                    [self addHit:clear action:@"clearDone" ident:nil label:ShiroL(@"clearDone")];
                }
                [self drawRoundButton:collapsed ? @"chevRight" : @"chevDown" rect:chev action:@"doneToggle" ident:nil label:ShiroL(collapsed ? @"expand" : @"collapse") ink:ink base:.09];
            } else {
                NSRect num = NSMakeRect(14, hm - 13, 26, 26);
                FillCircle(num, A(ink, .12));
                NSString *numText = [NSString stringWithFormat:@"%ld", (long)item.band + 1];
                NSFont *numFont = ShiroTextFont(12, 600);
                DrawText(numText, NSMidX(num) - TextSize(numText, numFont, 0).width / 2, hm, numFont, ink, 0, NO);
                if ([self.editKind isEqual:@"renameSection"] && [self.editTarget isEqual:item.sectionID]) {
                    [self drawFormRow:NSMakeRect(50, y + 3, W - 8 - 50, kSecHeadH - 6) inputX:50 marker:nil ink:ink fill:fill top:top];
                    editorPlaced = YES;
                } else {
                    BOOL collapsed = [section[@"collapsed"] boolValue];
                    NSArray *all = [self.store tasksInSectionID:item.sectionID];
                    NSInteger done = 0; for (NSDictionary *x in all) if ([x[@"done"] boolValue]) done++;
                    CGFloat nameMax = NSMinX(plus) - 12 - 50 - 40;
                    NSFont *nameFont = ShiroTextFont(15, 600);
                    CGFloat nameW = MIN(TextSize(section[@"title"], nameFont, 0).width, nameMax);
                    DrawTextInWidth(section[@"title"], 50, hm, nameW + 2, nameFont, ink, NO);
                    DrawText([NSString stringWithFormat:@"%ld/%lu", (long)done, (unsigned long)all.count], 50 + nameW + 10, hm, ShiroTextFont(12, 600), A(ink, .55), 0.4, NO);
                    [self addHit:NSMakeRect(0, y, NSMinX(plus) - 4, kSecHeadH) action:@"sectionHead" ident:item.sectionID label:section[@"title"]];
                    [self drawRoundButton:@"plus" rect:plus action:@"plus" ident:item.sectionID label:[NSString stringWithFormat:@"%@ %@", ShiroL(@"addTaskTo"), section[@"title"]] ink:ink base:.09];
                    [self drawRoundButton:@"more" rect:more action:@"sectionMore" ident:item.sectionID label:ShiroL(@"sectionActions") ink:ink base:.09];
                    [self drawRoundButton:collapsed ? @"chevRight" : @"chevDown" rect:chev action:@"collapse" ident:item.sectionID label:ShiroL(collapsed ? @"expand" : @"collapse") ink:ink base:.09];
                }
            }
        }
        else if ([item.kind isEqual:@"taskForm"]) {
            [A(ink, .14) setFill]; FillRect(NSMakeRect(52, y, W - 62, 1));
            [self drawFormRow:NSMakeRect(52, y, W - 62, item.h) inputX:kTitleX marker:[self.editKind isEqual:@"link"] ? @"link" : ([self.editKind isEqual:@"task"] || [self.editKind isEqual:@"fileTask"] ? @"dash" : @"circle") ink:ink fill:fill top:top];
            if ([self.editKind isEqual:@"renameTask"]) {
                NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(55, y + 11, 18, 18)];
                circle.lineWidth = 2; [ink setStroke]; [circle stroke];
            }
            editorPlaced = YES;
        }
        else if ([item.kind isEqual:@"empty"]) {
            [A(ink, .14) setFill]; FillRect(NSMakeRect(52, y, W - 62, 1));
            DrawText(ShiroL(@"empty"), 54, y + kRowH / 2, ShiroTextFont(14, 400), A(ink, .55), 0, NO);
        }
        else if (task && ([item.kind isEqual:@"row"] || [item.kind isEqual:@"doneRow"])) {
            BOOL doneRow = [item.kind isEqual:@"doneRow"];
            NSString *tid = item.taskID;
            BOOL selected = !doneRow && [self.store.activeTaskID isEqual:tid];
            CGFloat firstMid = y + 20;
            if ([self hovered:@"row" ident:tid] || [self hovered:@"check" ident:tid] || [self hovered:@"more" ident:tid] || [self hovered:@"link" ident:tid]) {
                [A(ink, .05) setFill]; FillRect(NSMakeRect(52, y, W - 62, item.h));
            }
            [A(ink, .14) setFill]; FillRect(NSMakeRect(52, y, W - 62, 1));
            // The row goes first so the circle, "•••" and the link, added later, win the click.
            [self addHit:NSMakeRect(0, y, W - 10 - 30, item.h) action:doneRow ? @"doneRow" : @"row" ident:tid label:task[@"title"]];
            if (selected) { NSRect go = NSMakeRect(14, firstMid - 12, 24, 24); FillCircle(go, ink); DrawIcon(@"arrow", go, 14, fill, 2.6); }
            NSRect check = NSMakeRect(54, firstMid - 10, 20, 20);
            if (doneRow) { FillCircle(check, A(ink, .8)); DrawIcon(@"check", check, 12, fill, 3); }
            else {
                NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(check, 1, 1)];
                circle.lineWidth = 2; [ink setStroke]; [circle stroke];
            }
            [self addHit:NSInsetRect(check, -6, -8) action:@"check" ident:tid label:ShiroL(doneRow ? @"backToActive" : @"markDone")];
            NSRect moreRect = NSMakeRect(W - 10 - 30, firstMid - 15, 30, 30);
            if ([self hovered:@"more" ident:tid]) FillCircle(moreRect, A(ink, .12));
            DrawIcon(@"more", moreRect, 16, A(ink, .7), 2);
            [self addHit:moreRect action:@"more" ident:tid label:ShiroL(@"taskActions")];
            CGFloat right = NSMinX(moreRect) - 8;
            if (doneRow) {
                NSString *name = section[@"title"] ?: @"";
                DrawTextInWidth(name, right - 82, firstMid, 82, ShiroTextFont(12, 500), A(ink, .5), NO);
            } else if ([self.scope isEqual:@"task"]) {
                double remaining = selected && [self.timer.phase isEqual:@"work"] ? [self.timer remainingAt:self.now] : [self.store remainingForTaskID:tid];
                if (remaining < 0) remaining = self.timer.workSeconds;
                DrawText([self timeText:remaining], right, firstMid, ShiroDisplayFont(12, 400), A(ink, .6), 0, YES);
            }
            CGFloat width = [self titleWidthDone:doneRow];
            NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
            para.lineBreakMode = NSLineBreakByWordWrapping;
            NSMutableDictionary *style = [@{NSFontAttributeName:[self titleFontSelected:selected], NSForegroundColorAttributeName:doneRow ? A(ink, .5) : ink, NSParagraphStyleAttributeName:para} mutableCopy];
            if (doneRow) style[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
            [task[@"title"] drawWithRect:NSMakeRect(kTitleX, y + 10, width, item.titleH + 2) options:NSStringDrawingUsesLineFragmentOrigin attributes:style];
            NSString *link = task[@"link"];
            if (link.length) {
                // Finished tasks keep their link, a little quieter.
                CGFloat ly = y + 10 + item.titleH + 9;
                BOOL hover = [self hovered:@"link" ident:tid];
                CGFloat rest = doneRow ? .4 : .55;
                DrawIcon(@"link", NSMakeRect(kTitleX - 1, ly - 7, 14, 14), 13, A(ink, hover ? .9 : rest), 2);
                NSFont *f = ShiroTextFont(12, 500);
                CGFloat lw = MIN(TextSize([self linkLabel:link], f, 0).width, width - 20);
                DrawTextInWidth([self linkLabel:link], kTitleX + 18, ly, lw + 2, f, A(ink, hover ? .9 : rest), NO);
                if (hover) { [A(ink, .5) setFill]; FillRect(NSMakeRect(kTitleX + 18, ly + 8, lw, 1)); }
                [self addHit:NSMakeRect(kTitleX - 4, ly - 10, lw + 26, 20) action:@"link" ident:tid label:[NSString stringWithFormat:@"%@: %@", ShiroL(@"openLink"), [self linkLabel:link]]];
            }
        }
        if (faded) { CGContextEndTransparencyLayer(cg); CGContextRestoreGState(cg); }
    }

    // Drop markers
    if (self.dragging && self.dragSection && self.dropGap >= 0) {
        NSArray<ShiroBlock *> *sections = [self sectionBlocks];
        CGFloat ly = self.dropGap < (NSInteger)sections.count ? sections[(NSUInteger)self.dropGap].top : sections.lastObject.bottom;
        FillRound(NSMakeRect(12, top + ly - 1.5, W - 24, 3), 1.5, t.ink);
    }
    if (self.dragging && self.dragTask && self.drop && !isnan(self.drop.lineY)) {
        NSUInteger index = [self.store.sections indexOfObject:[self.store sectionWithID:self.drop.sectionID]];
        FillRound(NSMakeRect(48, top + self.drop.lineY - 1.5, W - 58, 3), 1.5, index == NSNotFound ? t.ink : [t bandInkAt:index]);
    }

    if (self.editor) {
        self.editor.hidden = !editorPlaced;
        if (editorPlaced) [self positionEditor];
    }
    for (ShiroHit *hit in self.hits)
        if (![@[@"toggle", @"reset", @"phase", @"settings", @"close"] containsObject:hit.action])
            hit.rect = NSIntersectionRect(hit.rect, NSMakeRect(0, kHeadH, W, H - kHeadH));
}
- (NSArray<ShiroBlock *> *)sectionBlocks {
    NSMutableArray *list = [NSMutableArray array];
    for (ShiroBlock *b in self.blocks) if (b.sectionID) [list addObject:b];   // sections and the file block, in screen order
    return list;
}
// The file task shown right after a fileSection label.
- (NSInteger)fileIndexAfter:(ShiroItem *)label {
    NSUInteger at = [self.items indexOfObjectIdenticalTo:label];
    for (NSUInteger i = at + 1; i < self.items.count; i++)
        if ([self.items[i].kind isEqual:@"fileRow"]) return [[self.items[i].taskID substringFromIndex:5] integerValue];
    return 0;
}

#pragma mark Editing

- (void)updateEditorStyle {
    if (!self.editor) return;
    NSColor *ink = self.theme.ink;
    if ([self.editKind isEqual:@"fileTask"]) ink = self.theme.popoverInk;
    else if (![self.editKind isEqual:@"section"]) {
        NSString *sid = [self.editKind isEqual:@"task"] || [self.editKind isEqual:@"renameSection"] ? self.editTarget : [self.store taskWithID:self.editTarget][@"sectionID"];
        NSUInteger index = [self.store.sections indexOfObject:[self.store sectionWithID:sid]];
        if (index != NSNotFound) ink = [self.theme bandInkAt:index];
    }
    self.editor.textColor = ink;
    self.editor.font = ShiroTextFont(15 * self.k, [self.editKind isEqual:@"renameSection"] ? 600 : 400);
    NSString *key = [self.editKind isEqual:@"section"] || [self.editKind isEqual:@"renameSection"] ? @"sectionName" : [self.editKind isEqual:@"renameTask"] ? @"taskName" : [self.editKind isEqual:@"link"] ? @"linkPlaceholder" : @"newTask";
    self.editor.placeholderAttributedString = [[NSAttributedString alloc] initWithString:ShiroL(key) attributes:@{NSForegroundColorAttributeName:A(ink, .42), NSFontAttributeName:self.editor.font}];
    self.editor.cell.accessibilityLabel = ShiroL(key);
    NSText *fieldEditor = self.editor.currentEditor;
    if ([fieldEditor isKindOfClass:NSTextView.class]) ((NSTextView *)fieldEditor).insertionPointColor = ink;
}
- (void)positionEditor { self.editor.frame = [self toView:self.editorRect]; }   // editorRect already includes scrolling
- (void)startEditing:(NSString *)kind target:(NSString *)target text:(NSString *)text {
    if (self.editKind) [self commitEditContinuing:NO];
    if (self.editKind) [self endEditing];   // saving a new section opens its first task row; this request wins
    self.editKind = kind; self.editTarget = target;
    ShiroEditor *editor = [[ShiroEditor alloc] initWithFrame:NSZeroRect];
    editor.bezeled = NO; editor.bordered = NO; editor.drawsBackground = NO; editor.focusRingType = NSFocusRingTypeNone;
    editor.stringValue = text ?: @""; editor.delegate = self;
    // Long titles wrap instead of running off the edge; Return still saves.
    editor.usesSingleLineMode = NO; editor.cell.wraps = YES; editor.cell.scrollable = NO; editor.lineBreakMode = NSLineBreakByWordWrapping;
    self.editor = editor; [self updateEditorStyle];
    [self addSubview:editor];
    [self.delegate panelContentHeightChanged];
    [self display];
    [self scrollEditorIntoView];
    [self.window makeFirstResponder:editor];
    NSText *fieldEditor = editor.currentEditor;
    if (fieldEditor) fieldEditor.selectedRange = NSMakeRange(fieldEditor.string.length, 0);
    [self updateEditorStyle];
    self.needsDisplay = YES;
}
- (void)scrollEditorIntoView {
    CGFloat top = NSMinY(self.editorRect) - 12, bottom = NSMaxY(self.editorRect) + 16, H = self.logicalSize.height;
    if (bottom > H) self.scrollY += bottom - H;
    else if (top < kHeadH) self.scrollY -= kHeadH - top;
    [self clampScroll];
    [self display];
}
- (void)endEditing {
    if (!self.editor) { self.editKind = nil; self.editTarget = nil; return; }
    self.finishingEdit = YES;
    ShiroEditor *editor = self.editor;
    self.editor = nil; self.editKind = nil; self.editTarget = nil;
    if (self.window.firstResponder == editor.currentEditor) [self.window makeFirstResponder:self];
    [editor removeFromSuperview];
    self.finishingEdit = NO;
    [self clampScroll];
    self.needsDisplay = YES;
    [self.delegate panelContentHeightChanged];
}
// Saves what was typed. A link may be saved empty (that removes it); empty titles are dropped.
- (void)commitEditContinuing:(BOOL)continueAdding {
    if (!self.editKind) return;
    NSString *text = [self.editor.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *kind = self.editKind, *target = self.editTarget;
    [self endEditing];
    if ([kind isEqual:@"link"]) { [self.delegate panelSetLink:text forTask:target]; return; }
    if (!text.length) return;
    if ([kind isEqual:@"task"]) {
        [self.delegate panelAddTask:text toSection:target];
        if (continueAdding) [self beginAddingTaskToSection:target];
    } else if ([kind isEqual:@"fileTask"]) {
        [self.delegate panelAddTaskToFile:text];
        if (continueAdding) [self startEditing:@"fileTask" target:@"file" text:@""];
    } else if ([kind isEqual:@"section"]) {
        NSString *created = [self.delegate panelAddSection:text];
        if (created) [self beginAddingTaskToSection:created];
    }
    else if ([kind isEqual:@"renameTask"]) [self.delegate panelRenameTask:target title:text];
    else if ([kind isEqual:@"renameSection"]) [self.delegate panelRenameSection:target title:text];
}
- (void)beginAddingTaskToSection:(NSString *)sectionID {
    if (self.editKind) [self commitEditContinuing:NO];
    [self.delegate panelExpandSection:sectionID];
    [self startEditing:@"task" target:sectionID text:@""];
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    // Return saves; in a new-task row it also opens the next empty row. Option-Return is not needed: titles wrap by themselves.
    if (command == @selector(insertNewline:) || command == @selector(insertLineBreak:)) { [self commitEditContinuing:[self.editKind isEqual:@"task"] || [self.editKind isEqual:@"fileTask"]]; return YES; }
    if (command == @selector(cancelOperation:)) { [self endEditing]; return YES; }
    return NO;
}
- (void)controlTextDidChange:(NSNotification *)note { [self.delegate panelContentHeightChanged]; self.needsDisplay = YES; }
- (void)controlTextDidBeginEditing:(NSNotification *)note { [self updateEditorStyle]; self.needsDisplay = YES; }
- (void)controlTextDidEndEditing:(NSNotification *)note {
    // Tab or focus moving elsewhere keeps the text, like a click outside.
    if (!self.finishingEdit && self.editKind) [self commitEditContinuing:NO];
    self.needsDisplay = YES;
}
- (void)cancelOperation:(id)sender { if (self.editKind) [self endEditing]; else [self.delegate panelClose]; }

#pragma mark Mouse

- (NSString *)actionAt:(NSPoint)point { return [self hitAt:point].action; }
- (ShiroHit *)hitAt:(NSPoint)point {
    for (ShiroHit *hit in self.hits.reverseObjectEnumerator) if (NSPointInRect(point, hit.rect)) return hit;
    return nil;
}
- (void)mouseMoved:(NSEvent *)event {
    ShiroHit *hit = [self hitAt:[self logicalPoint:event]];
    NSString *key = hit ? [self keyFor:hit.action ident:hit.ident] : nil;
    if (key != self.hoverKey && ![key isEqual:self.hoverKey]) { self.hoverKey = key; self.needsDisplay = YES; }
    NSCursor *cursor = [hit.action isEqual:@"link"] || [hit.action isEqual:@"fileLink"] ? NSCursor.pointingHandCursor : NSCursor.arrowCursor;
    [cursor set];
}
- (void)mouseExited:(NSEvent *)event { if (self.hoverKey) { self.hoverKey = nil; self.needsDisplay = YES; } [NSCursor.arrowCursor set]; }
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self logicalPoint:event];
    ShiroHit *hit = [self hitAt:point];
    self.pressAction = hit.action; self.pressIdent = hit.ident; self.pressPoint = point;
    self.dragging = NO; self.drop = nil; self.dropGap = -1;
    self.dragSection = [hit.action isEqual:@"sectionHead"] ? hit.ident : ([hit.action isEqual:@"fileHeader"] ? @"file" : nil);
    self.dragTask = ([hit.action isEqual:@"row"] || [hit.action isEqual:@"doneRow"] || [hit.action isEqual:@"fileRow"]) ? hit.ident : nil;
    if (!hit && self.editKind) [self commitEditContinuing:NO];
    if (!hit && point.y < kBarH) [self.window performWindowDragWithEvent:event];
}
- (ShiroDrop *)dropForListY:(CGFloat)listY {
    // A collapsed section or the done list takes the task as a whole; open sections show the exact gap.
    // Tasks from the file can only be copied into Shiro's own sections; nothing is dropped onto the file.
    BOOL fromFile = [self.dragTask hasPrefix:@"file:"];
    for (ShiroBlock *block in self.blocks) {
        if (listY < block.top || listY >= block.bottom) continue;
        // Inside the file block a file task changes places (Shiro's own order; the file is not touched).
        if ([block.sectionID isEqual:@"file"] && fromFile && !block.collapsed) return [self fileDropForListY:listY];
        if ([block.sectionID isEqual:@"file"] || (fromFile && !block.sectionID)) return nil;
        if (!block.sectionID || block.collapsed) { ShiroDrop *d = [[ShiroDrop alloc] init]; d.sectionID = block.sectionID; d.lineY = NAN; return d; }
    }
    if (!fromFile && self.blocks.count && listY >= self.blocks.lastObject.bottom && !self.blocks.lastObject.sectionID) { ShiroDrop *d = [[ShiroDrop alloc] init]; d.lineY = NAN; return d; }
    ShiroDrop *best = nil; CGFloat bestDistance = CGFLOAT_MAX;
    for (ShiroBlock *block in self.blocks) {
        if (!block.sectionID || block.collapsed || [block.sectionID isEqual:@"file"]) continue;
        NSMutableArray *gaps = [NSMutableArray array];
        CGFloat endY = block.top + kSecHeadH;
        for (ShiroItem *item in self.items) {
            if (![item.sectionID isEqual:block.sectionID] || item.band < 0) continue;
            if ([item.kind isEqual:@"row"]) { [gaps addObject:@[@(item.y), item.taskID]]; endY = item.y + item.h; }
            else if ([item.kind isEqual:@"empty"] || [item.kind isEqual:@"taskForm"]) endY = MAX(endY, item.y + item.h);
        }
        [gaps addObject:@[@(endY), [NSNull null]]];
        for (NSArray *gap in gaps) {
            CGFloat distance = fabs([gap[0] doubleValue] - listY);
            if (distance < bestDistance) {
                bestDistance = distance; best = [[ShiroDrop alloc] init];
                best.sectionID = block.sectionID; best.lineY = [gap[0] doubleValue]; best.beforeID = gap[1] == [NSNull null] ? nil : gap[1];
            }
        }
    }
    return best;
}
- (ShiroDrop *)fileDropForListY:(CGFloat)listY {
    NSMutableArray *gaps = [NSMutableArray array];   // @[y, beforeIndex or -1, section]
    NSArray *rows = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"kind == 'fileRow'"]];
    for (NSUInteger i = 0; i < rows.count; i++) {
        ShiroItem *row = rows[i];
        NSInteger index = [[row.taskID substringFromIndex:5] integerValue];
        NSString *section = self.fileTasks[(NSUInteger)index].section ?: @"";
        [gaps addObject:@[@(row.y), @(index), section]];
        BOOL last = i + 1 == rows.count;
        NSString *nextSection = last ? nil : self.fileTasks[(NSUInteger)[[[rows[i + 1] taskID] substringFromIndex:5] integerValue]].section;
        if (last || ![nextSection isEqual:section]) [gaps addObject:@[@(row.y + row.h), @(-1), section]];
    }
    ShiroDrop *best = nil; CGFloat bestDistance = CGFLOAT_MAX;
    for (NSArray *gap in gaps) {
        CGFloat distance = fabs([gap[0] doubleValue] - listY);
        if (distance >= bestDistance) continue;
        bestDistance = distance;
        best = [[ShiroDrop alloc] init];
        best.sectionID = @"file"; best.lineY = [gap[0] doubleValue];
        best.beforeID = [gap[1] integerValue] >= 0 ? [NSString stringWithFormat:@"file:%@|%@", gap[1], gap[2]] : [@"end|" stringByAppendingString:gap[2]];
    }
    return best;
}
- (void)mouseDragged:(NSEvent *)event {
    if (!self.dragSection && !self.dragTask) return;
    NSPoint point = [self logicalPoint:event];
    if (!self.dragging && hypot(point.x - self.pressPoint.x, point.y - self.pressPoint.y) > 4) {
        if (self.editKind) [self commitEditContinuing:NO];
        self.dragging = YES; [NSCursor.closedHandCursor push];
        [self.delegate panelContentHeightChanged];   // the done list appears as a drop target while a task is dragged
    }
    if (!self.dragging) return;
    if (point.y > self.logicalSize.height - 24) self.scrollY += 8; else if (point.y < kHeadH + 24) self.scrollY -= 8;
    [self clampScroll];
    CGFloat listY = point.y - kHeadH + self.scrollY;
    [self layout];
    if (self.dragSection) {
        NSArray<ShiroBlock *> *sections = [self sectionBlocks];
        NSInteger gap = 0;
        for (NSUInteger i = 0; i < sections.count; i++) if (listY > (sections[i].top + sections[i].bottom) / 2) gap = (NSInteger)i + 1;
        self.dropGap = gap;
    } else self.drop = [self dropForListY:listY];
    self.needsDisplay = YES;
}
- (void)mouseUp:(NSEvent *)event {
    NSPoint point = [self logicalPoint:event];
    if (self.dragging) {
        [NSCursor pop];
        NSString *section = self.dragSection, *taskID = self.dragTask;
        ShiroDrop *drop = self.drop; NSInteger gap = self.dropGap;
        self.dragging = NO; self.dragSection = nil; self.dragTask = nil; self.drop = nil; self.dropGap = -1;
        if (section) {
            NSMutableArray *keys = [NSMutableArray array];
            for (ShiroBlock *b in [self sectionBlocks]) [keys addObject:b.sectionID];
            NSInteger old = (NSInteger)[keys indexOfObject:section];
            NSInteger target = gap > old ? gap - 1 : gap;
            if (old != NSNotFound && gap >= 0 && target != old) {
                [keys removeObjectAtIndex:(NSUInteger)old];
                [keys insertObject:section atIndex:(NSUInteger)MIN(target, (NSInteger)keys.count)];
                [self.delegate panelReorderBlocks:keys];
            }
        } else if ([taskID hasPrefix:@"file:"]) {
            NSInteger index = [[taskID substringFromIndex:5] integerValue];
            if ([drop.sectionID isEqual:@"file"]) {
                NSArray *parts = [drop.beforeID componentsSeparatedByString:@"|"];
                NSInteger before = [parts[0] hasPrefix:@"file:"] ? [[parts[0] substringFromIndex:5] integerValue] : -1;
                NSString *section = parts.count > 1 ? [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@"|"] : @"";
                if (before != index) [self.delegate panelMoveFileTask:index before:before section:section];
            }
            else if (drop.sectionID) [self.delegate panelImportFileTask:index toSection:drop.sectionID before:drop.beforeID];
        } else if (taskID && drop) {
            BOOL done = [[self.store taskWithID:taskID][@"done"] boolValue];
            if (!drop.sectionID) { if (!done) [self.delegate panelToggleTask:taskID]; }
            else [self.delegate panelMoveTask:taskID toSection:drop.sectionID before:drop.beforeID];
        }
        [self.delegate panelContentHeightChanged];
        self.needsDisplay = YES;
        return;
    }
    self.dragSection = nil; self.dragTask = nil;
    ShiroHit *hit = [self hitAt:point];
    if (!hit || ![hit.action isEqual:self.pressAction] || !(hit.ident == self.pressIdent || [hit.ident isEqual:self.pressIdent])) return;
    // Double click on a task or a section name edits it in place.
    if (event.clickCount >= 2 && [hit.action isEqual:@"row"]) { [self startEditing:@"renameTask" target:hit.ident text:[self.store taskWithID:hit.ident][@"title"]]; return; }
    if (event.clickCount >= 2 && [hit.action isEqual:@"sectionHead"]) { [self startEditing:@"renameSection" target:hit.ident text:[self.store sectionWithID:hit.ident][@"title"]]; return; }
    [self perform:hit.action ident:hit.ident rect:hit.rect event:event];
}
- (void)perform:(NSString *)action ident:(NSString *)ident rect:(NSRect)rect event:(NSEvent *)event {
    if ([action isEqual:@"formOK"]) { [self commitEditContinuing:NO]; return; }
    if ([action isEqual:@"formCancel"]) { [self endEditing]; return; }
    // Any other click keeps what was typed and then does its own thing (for example "+" opens the next row).
    if (self.editKind && ![action isEqual:@"sectionHead"]) [self commitEditContinuing:NO];
    id<ShiroPanelDelegate> d = self.delegate;
    if ([action isEqual:@"toggle"]) [d panelToggleTimer];
    else if ([action isEqual:@"reset"]) [d panelResetTimer];
    else if ([action isEqual:@"phase"]) [d panelSwitchToPhase:ident];
    else if ([action isEqual:@"settings"]) [d panelShowSettingsFromRect:[self toView:rect]];
    else if ([action isEqual:@"close"]) [d panelClose];
    else if ([action isEqual:@"addSection"]) [self startEditing:@"section" target:nil text:@""];
    else if ([action isEqual:@"plus"]) [self beginAddingTaskToSection:ident];
    else if ([action isEqual:@"collapse"]) [d panelToggleSection:ident];
    else if ([action isEqual:@"doneHeader"] || [action isEqual:@"doneToggle"]) [d panelToggleDoneList];
    else if ([action isEqual:@"clearDone"]) [self confirmClearDone];
    else if ([action isEqual:@"row"]) [d panelSelectTask:ident];
    else if ([action isEqual:@"check"]) [d panelToggleTask:ident];
    else if ([action isEqual:@"link"]) [self openLinkOf:ident];
    else if ([action isEqual:@"fileHeader"] || [action isEqual:@"fileToggle"]) [d panelToggleFileBlock];
    else if ([action isEqual:@"fileAdd"]) { if (self.fileCollapsed) [d panelToggleFileBlock]; [self startEditing:@"fileTask" target:@"file" text:@""]; }
    else if ([action isEqual:@"fileRow"]) [d panelSelectFileTask:[[ident substringFromIndex:5] integerValue]];
    else if ([action isEqual:@"fileCheck"]) [d panelToggleFileTask:[[ident substringFromIndex:5] integerValue]];
    else if ([action isEqual:@"import"]) [d panelImportFileTask:[[ident substringFromIndex:5] integerValue] fromRect:[self toView:rect]];
    else if ([action isEqual:@"fileLink"]) [self openLink:self.fileTasks[(NSUInteger)[[ident substringFromIndex:5] integerValue]].link];
    else if ([action isEqual:@"more"] || [action isEqual:@"sectionMore"]) [self showMenuFor:action ident:ident rect:rect];
}
- (void)openLinkOf:(NSString *)taskID { [self openLink:[self.store taskWithID:taskID][@"link"]]; }
- (void)openLink:(NSString *)link {
    if (!link.length) return;
    if (![link containsString:@"://"] && ![link.lowercaseString hasPrefix:@"mailto:"]) link = [@"https://" stringByAppendingString:link];
    NSURL *url = [NSURL URLWithString:link] ?: [NSURL URLWithString:[link stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLFragmentAllowedCharacterSet]];
    if (url) [NSWorkspace.sharedWorkspace openURL:url];
}
- (void)confirmClearDone {
    NSInteger count = (NSInteger)self.store.doneTasks.count;
    if (!count) return;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = ShiroClearDoneQuestion(count);
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:ShiroL(@"deleteForever")]; [alert addButtonWithTitle:ShiroL(@"cancel")];
    alert.buttons.firstObject.hasDestructiveAction = YES;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) [self.delegate panelClearDone];
    }];
}
- (void)showMenuFor:(NSString *)action ident:(NSString *)ident rect:(NSRect)rect {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMutableArray *entries = [NSMutableArray array];
    if ([action isEqual:@"sectionMore"]) [entries addObjectsFromArray:@[@[@"renameSection", @"renameSection"], @[@"deleteSection", @"deleteSection"]]];
    else if ([[self.store taskWithID:ident][@"done"] boolValue]) [entries addObjectsFromArray:@[@[@"backToActive", @"reopen"], @[@"deleteForever", @"delete"]]];
    else {
        BOOL hasLink = [[self.store taskWithID:ident][@"link"] length] > 0;
        [entries addObject:@[@"rename", @"rename"]];
        [entries addObject:@[hasLink ? @"editLink" : @"attachLink", @"link"]];
        if (hasLink) [entries addObject:@[@"removeLink", @"removeLink"]];
        [entries addObject:@[@"delete", @"delete"]];
    }
    for (NSArray *entry in entries) {
        if ([entry[1] isEqual:@"delete"] || [entry[1] isEqual:@"deleteSection"]) [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:ShiroL(entry[0]) action:@selector(menuChoose:) keyEquivalent:@""];
        item.target = self; item.representedObject = @[entry[1], ident];
        [menu addItem:item];
    }
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(NSMinX(rect) * self.k, (NSMaxY(rect) + 4) * self.k) inView:self];
}
- (void)menuChoose:(NSMenuItem *)item {
    NSString *what = item.representedObject[0], *ident = item.representedObject[1];
    NSDictionary *task = [self.store taskWithID:ident];
    if ([what isEqual:@"rename"]) [self startEditing:@"renameTask" target:ident text:task[@"title"]];
    else if ([what isEqual:@"link"]) [self startEditing:@"link" target:ident text:task[@"link"]];
    else if ([what isEqual:@"removeLink"]) [self.delegate panelSetLink:@"" forTask:ident];
    else if ([what isEqual:@"reopen"]) [self.delegate panelToggleTask:ident];
    else if ([what isEqual:@"delete"]) [self.delegate panelDeleteTask:ident];
    else if ([what isEqual:@"renameSection"]) [self startEditing:@"renameSection" target:ident text:[self.store sectionWithID:ident][@"title"]];
    else if ([what isEqual:@"deleteSection"]) {
        NSInteger count = (NSInteger)[self.store tasksInSectionID:ident].count;
        if (!count) { [self.delegate panelDeleteSection:ident]; return; }
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = ShiroDeleteSectionQuestion([self.store sectionWithID:ident][@"title"], count);
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:ShiroL(@"delete")]; [alert addButtonWithTitle:ShiroL(@"cancel")];
        alert.buttons.firstObject.hasDestructiveAction = YES;
        [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
            if (response == NSAlertFirstButtonReturn) [self.delegate panelDeleteSection:ident];
        }];
    }
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement { return NO; }
- (void)rebuildAccessibility {
    NSMutableArray *elements = [NSMutableArray array];
    __weak ShiroPanelView *weakSelf = self;
    for (ShiroHit *hit in self.hits) {
        if (NSIsEmptyRect(hit.rect) || [hit.action isEqual:@"sectionHead"]) continue;
        ShiroAXButton *element = [ShiroAXButton accessibilityElementWithRole:NSAccessibilityButtonRole frame:NSZeroRect label:hit.label parent:self];
        NSRect r = hit.rect, v = [self toView:r];
        element.accessibilityFrameInParentSpace = NSMakeRect(NSMinX(v), self.bounds.size.height - NSMaxY(v), v.size.width, v.size.height);
        NSString *action = hit.action, *ident = hit.ident;
        element.press = ^{ [weakSelf perform:action ident:ident rect:r event:nil]; };
        [elements addObject:element];
    }
    self.axElements = elements;
}
- (NSArray *)accessibilityChildren {
    NSMutableArray *children = [self.axElements mutableCopy] ?: [NSMutableArray array];
    if (self.editor) [children addObject:self.editor];
    return children;
}
@end

#pragma mark - Settings

@interface ShiroThemeGrid : NSView
@property(nonatomic, copy) NSString *selected;
@property(nonatomic, copy) void (^choose)(NSString *identifier);
@end
@implementation ShiroThemeGrid
- (BOOL)isFlipped { return YES; }
- (NSRect)cellAt:(NSInteger)i { CGFloat w = self.bounds.size.width / 4; return NSMakeRect((i % 4) * w, (i / 4) * 62, w, 62); }
- (void)drawRect:(NSRect)dirty {
    NSArray *themes = ShiroTheme.all;
    for (NSInteger i = 0; i < (NSInteger)themes.count; i++) {
        ShiroTheme *t = themes[i];
        NSRect cell = [self cellAt:i], sw = NSMakeRect(NSMidX(cell) - 18, NSMinY(cell) + 4, 36, 36);
        NSArray *colors = @[t.headBackground, [t bandFillAt:0], [t bandFillAt:1], [t bandFillAt:2]];
        for (NSInteger q = 0; q < 4; q++) {
            NSBezierPath *slice = [NSBezierPath bezierPath];
            [slice moveToPoint:Center(sw)];
            [slice appendBezierPathWithArcWithCenter:Center(sw) radius:18 startAngle:-90 + q * 90 endAngle:q * 90 clockwise:NO];
            [slice closePath]; [colors[q] setFill]; [slice fill];
        }
        NSBezierPath *edge = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(sw, .5, .5)];
        edge.lineWidth = 1; [[NSColor colorWithWhite:0 alpha:.12] setStroke]; [edge stroke];
        if ([t.identifier isEqual:self.selected]) {
            NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(sw, -4, -4)];
            ring.lineWidth = 2; [NSColor.labelColor setStroke]; [ring stroke];
        }
        NSFont *font = ShiroDisplayFont(12, 400);
        CGFloat w = TextSize(t.number, font, 0.3).width;
        DrawText(t.number, NSMidX(cell) - w / 2, NSMinY(cell) + 52, font, NSColor.labelColor, 0.3, NO);
    }
}
- (void)mouseUp:(NSEvent *)event {
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    NSArray *themes = ShiroTheme.all;
    for (NSInteger i = 0; i < (NSInteger)themes.count; i++) if (NSPointInRect(p, [self cellAt:i])) {
        self.selected = [themes[i] identifier]; self.needsDisplay = YES;
        if (self.choose) self.choose(self.selected);
    }
}
- (BOOL)isAccessibilityElement { return YES; }
- (NSAccessibilityRole)accessibilityRole { return NSAccessibilityRadioGroupRole; }
- (NSString *)accessibilityLabel { return ShiroL(@"theme"); }
- (id)accessibilityValue { return [ShiroTheme themeWithIdentifier:self.selected].number; }
@end

@interface ShiroFlippedView : NSView @end
@implementation ShiroFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface ShiroSettingsController ()
@property(nonatomic) NSTextField *titleLabel, *themeLabel, *timerLabel, *help, *workLabel, *breakLabel, *volumeLabel, *volumeValue, *soundLabel, *languageLabel, *sizeLabel, *fileLabel, *fileValue;
@property(nonatomic) NSTextField *workField, *breakField;
@property(nonatomic) NSPopUpButton *scopePopup, *packPopup;
@property(nonatomic) NSSlider *volume;
@property(nonatomic) NSButton *notify, *listen, *fileButton, *ambient;
@property(nonatomic) NSSlider *ambientVolume;
@property(nonatomic) NSTextField *ambientLabel;
@property(nonatomic) NSSegmentedControl *language, *size;
@property(nonatomic) ShiroThemeGrid *grid;
@end

static NSTextField *SettingsLabel(NSRect rect, CGFloat size, CGFloat weight, BOOL secondary) {
    NSTextField *field = [NSTextField labelWithString:@""];
    field.frame = rect; field.font = ShiroTextFont(size, weight);
    field.textColor = secondary ? NSColor.secondaryLabelColor : NSColor.labelColor;
    return field;
}

@implementation ShiroSettingsController
- (void)loadView {
    CGFloat W = 300, P = 16, inner = W - 2 * P;
    ShiroFlippedView *view = [[ShiroFlippedView alloc] initWithFrame:NSMakeRect(0, 0, W, 520)];
    self.titleLabel = SettingsLabel(NSMakeRect(P, 14, inner, 20), 15, 600, NO);
    self.themeLabel = SettingsLabel(NSMakeRect(P, 44, inner, 18), 13, 400, YES);
    self.grid = [[ShiroThemeGrid alloc] initWithFrame:NSMakeRect(P - 4, 66, inner + 8, 124)];
    __weak ShiroSettingsController *weakSelf = self;
    self.grid.choose = ^(NSString *identifier) { [weakSelf.delegate settingsChangedTheme:identifier]; [weakSelf refresh]; };
    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(P, 196, inner, 1)]; line.boxType = NSBoxSeparator;
    self.timerLabel = SettingsLabel(NSMakeRect(P, 206, inner, 18), 13, 400, YES);
    self.scopePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(P - 3, 226, inner + 6, 26) pullsDown:NO];
    self.scopePopup.target = self; self.scopePopup.action = @selector(changeScope:);
    self.help = SettingsLabel(NSMakeRect(P, 256, inner, 34), 12, 400, YES);
    self.help.maximumNumberOfLines = 2; self.help.lineBreakMode = NSLineBreakByWordWrapping; self.help.cell.wraps = YES;
    CGFloat half = (inner - 10) / 2;
    self.workLabel = SettingsLabel(NSMakeRect(P, 296, half, 18), 13, 400, YES);
    self.breakLabel = SettingsLabel(NSMakeRect(P + half + 10, 296, half, 18), 13, 400, YES);
    NSNumberFormatter *(^formatter)(double) = ^NSNumberFormatter *(double max) {
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.allowsFloats = NO; f.minimum = @1; f.maximum = @(max); return f;
    };
    self.workField = [[NSTextField alloc] initWithFrame:NSMakeRect(P, 316, half, 26)];
    self.breakField = [[NSTextField alloc] initWithFrame:NSMakeRect(P + half + 10, 316, half, 26)];
    self.workField.formatter = formatter(180); self.breakField.formatter = formatter(60);
    for (NSTextField *f in @[self.workField, self.breakField]) { f.font = ShiroTextFont(15, 500); f.target = self; f.action = @selector(changeDurations:); f.bezelStyle = NSTextFieldRoundedBezel; }
    self.volumeLabel = SettingsLabel(NSMakeRect(P, 354, inner - 50, 18), 13, 400, YES);
    self.volumeValue = SettingsLabel(NSMakeRect(W - P - 50, 354, 50, 18), 13, 400, YES);
    self.volumeValue.alignment = NSTextAlignmentRight;
    self.volume = [NSSlider sliderWithValue:80 minValue:0 maxValue:100 target:self action:@selector(changeVolume:)];
    self.volume.frame = NSMakeRect(P, 374, inner, 22); self.volume.continuous = YES;
    self.soundLabel = SettingsLabel(NSMakeRect(P, 404, inner, 18), 13, 400, YES);
    self.packPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(P - 3, 424, inner - 40, 26) pullsDown:NO];
    self.packPopup.target = self; self.packPopup.action = @selector(changePack:);
    self.listen = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil] target:self action:@selector(preview:)];
    self.listen.frame = NSMakeRect(W - P - 34, 424, 34, 26); self.listen.bezelStyle = NSBezelStyleRounded;
    self.notify = [NSButton checkboxWithTitle:@"" target:self action:@selector(changeNotify:)];
    self.ambient = [NSButton checkboxWithTitle:@"" target:self action:@selector(changeAmbient:)];
    self.ambient.frame = NSMakeRect(P - 2, 460, inner + 2, 20);
    self.ambientLabel = SettingsLabel(NSMakeRect(P + 20, 486, 110, 18), 12, 400, YES);
    self.ambientVolume = [NSSlider sliderWithValue:35 minValue:0 maxValue:100 target:self action:@selector(changeAmbientVolume:)];
    self.ambientVolume.frame = NSMakeRect(P + 130, 484, inner - 130, 22); self.ambientVolume.continuous = YES;
    [view addSubview:self.ambient]; [view addSubview:self.ambientLabel]; [view addSubview:self.ambientVolume];
    self.notify.frame = NSMakeRect(P - 2, 516, inner + 2, 20);
    self.sizeLabel = SettingsLabel(NSMakeRect(P, 548, 150, 18), 13, 400, YES);
    self.size = [NSSegmentedControl segmentedControlWithLabels:@[@"S", @"M", @"L"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(changeSize:)];
    self.size.frame = NSMakeRect(W - P - 110, 544, 110, 24);
    self.languageLabel = SettingsLabel(NSMakeRect(P, 584, 120, 18), 13, 400, YES);
    self.language = [NSSegmentedControl segmentedControlWithLabels:@[@"Рус", @"Eng"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(changeLanguage:)];
    self.language.frame = NSMakeRect(W - P - 110, 580, 110, 24);
    NSBox *fileLine = [[NSBox alloc] initWithFrame:NSMakeRect(P, 618, inner, 1)]; fileLine.boxType = NSBoxSeparator;
    self.fileLabel = SettingsLabel(NSMakeRect(P, 630, inner, 18), 13, 400, YES);
    self.fileValue = SettingsLabel(NSMakeRect(P, 656, inner - 150, 18), 14, 500, NO);
    self.fileValue.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.fileButton = [NSButton buttonWithTitle:@"" target:self action:@selector(fileAction:)];
    self.fileButton.frame = NSMakeRect(W - P - 146, 650, 150, 28); self.fileButton.bezelStyle = NSBezelStyleRounded;
    [view addSubview:fileLine]; [view addSubview:self.fileLabel]; [view addSubview:self.fileValue]; [view addSubview:self.fileButton];
    for (NSView *v in @[self.titleLabel, self.themeLabel, self.grid, line, self.timerLabel, self.scopePopup, self.help, self.workLabel, self.breakLabel,
                        self.workField, self.breakField, self.volumeLabel, self.volumeValue, self.volume, self.soundLabel, self.packPopup, self.listen,
                        self.notify, self.sizeLabel, self.size, self.languageLabel, self.language]) [view addSubview:v];
    view.frame = NSMakeRect(0, 0, W, 692);
    self.view = view;
    self.preferredContentSize = view.frame.size;
    [self refresh];
}
- (void)refresh {
    if (!self.isViewLoaded) return;
    id<ShiroSettingsDelegate> d = self.delegate;
    self.titleLabel.stringValue = ShiroL(@"settings");
    self.themeLabel.stringValue = ShiroL(@"theme");
    self.grid.selected = d.themeID; self.grid.needsDisplay = YES;
    self.timerLabel.stringValue = ShiroL(@"timer");
    [self.scopePopup removeAllItems];
    [self.scopePopup addItemsWithTitles:@[ShiroL(@"scopeGlobal"), ShiroL(@"scopeTask")]];
    [self.scopePopup selectItemAtIndex:[d.scope isEqual:@"task"] ? 1 : 0];
    self.help.stringValue = ShiroL([d.scope isEqual:@"task"] ? @"helpTask" : @"helpGlobal");
    self.workLabel.stringValue = ShiroL(@"workMin"); self.breakLabel.stringValue = ShiroL(@"breakMin");
    // Do not overwrite a number while it is being typed.
    if (!self.workField.currentEditor) self.workField.integerValue = (NSInteger)llround(d.workMinutes);
    if (!self.breakField.currentEditor) self.breakField.integerValue = (NSInteger)llround(d.breakMinutes);
    self.volumeLabel.stringValue = ShiroL(@"volume");
    self.volume.doubleValue = round(d.volume * 100);
    self.volumeValue.stringValue = [NSString stringWithFormat:@"%.0f%%", round(d.volume * 100)];
    self.soundLabel.stringValue = ShiroL(@"sound");
    [self.packPopup removeAllItems];
    NSArray *packs = @[@"glass", @"wood", @"air"];
    for (NSString *pack in packs) { [self.packPopup addItemWithTitle:ShiroL(pack)]; self.packPopup.lastItem.representedObject = pack; }
    [self.packPopup selectItemAtIndex:MAX(0, (NSInteger)[packs indexOfObject:d.soundPack])];
    self.listen.toolTip = ShiroL(@"listen"); self.listen.accessibilityLabel = ShiroL(@"listen");
    self.ambient.title = ShiroL(@"ambient"); self.ambient.state = d.ambient ? NSControlStateValueOn : NSControlStateValueOff;
    self.ambientLabel.stringValue = ShiroL(@"ambientVolume");
    self.ambientVolume.doubleValue = round(d.ambientVolume * 100); self.ambientVolume.enabled = d.ambient;
    self.notify.title = ShiroL(@"notify"); self.notify.state = d.notify ? NSControlStateValueOn : NSControlStateValueOff;
    self.sizeLabel.stringValue = ShiroL(@"windowSize");
    NSUInteger step = 0; double best = 9;
    for (NSUInteger i = 0; i < ShiroScaleSteps().count; i++) if (fabs(ShiroScaleSteps()[i].doubleValue - d.uiScale) < best) { best = fabs(ShiroScaleSteps()[i].doubleValue - d.uiScale); step = i; }
    self.size.selectedSegment = (NSInteger)step;
    self.languageLabel.stringValue = ShiroL(@"language");
    NSString *file = d.linkedFileName;
    self.fileLabel.stringValue = ShiroL(@"fileTitle");
    self.fileValue.stringValue = file ?: ShiroL(@"fileNone");
    self.fileValue.textColor = file ? NSColor.labelColor : NSColor.secondaryLabelColor;
    self.fileButton.title = ShiroL(file ? @"disconnectFile" : @"connectFile");
    self.language.selectedSegment = [d.language isEqual:@"en"] ? 1 : 0;
    self.view.appearance = [NSAppearance appearanceNamed:[ShiroTheme themeWithIdentifier:d.themeID].dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
}
- (void)changeScope:(NSPopUpButton *)sender { [self.delegate settingsChangedScope:sender.indexOfSelectedItem == 1 ? @"task" : @"global"]; [self refresh]; }
- (void)changeDurations:(id)sender { [self.delegate settingsChangedWork:MAX(1, self.workField.doubleValue) breakMinutes:MAX(1, self.breakField.doubleValue)]; [self refresh]; }
- (void)changeVolume:(NSSlider *)sender {
    [self.delegate settingsChangedVolume:sender.doubleValue / 100];
    self.volumeValue.stringValue = [NSString stringWithFormat:@"%.0f%%", sender.doubleValue];
    NSEvent *event = NSApp.currentEvent;
    if (event.type == NSEventTypeLeftMouseUp) [self.delegate settingsPreviewSound];
}
- (void)changePack:(NSPopUpButton *)sender { [self.delegate settingsChangedSoundPack:sender.selectedItem.representedObject]; [self.delegate settingsPreviewSound]; }
- (void)preview:(id)sender { [self.delegate settingsPreviewSound]; }
- (void)changeNotify:(NSButton *)sender { [self.delegate settingsChangedNotify:sender.state == NSControlStateValueOn]; }
- (void)changeAmbient:(NSButton *)sender { [self.delegate settingsChangedAmbient:sender.state == NSControlStateValueOn]; [self refresh]; }
- (void)changeAmbientVolume:(NSSlider *)sender { [self.delegate settingsChangedAmbientVolume:sender.doubleValue / 100]; }
- (void)fileAction:(id)sender { if (self.delegate.linkedFileName) [self.delegate settingsDisconnectFile]; else [self.delegate settingsConnectFile]; [self refresh]; }
- (void)changeSize:(NSSegmentedControl *)sender { [self.delegate settingsChangedScale:ShiroScaleSteps()[(NSUInteger)MAX(0, sender.selectedSegment)].doubleValue]; }
- (void)changeLanguage:(NSSegmentedControl *)sender { [self.delegate settingsChangedLanguage:sender.selectedSegment == 1 ? @"en" : @"ru"]; [self refresh]; }
@end

void ShiroDrawViewTree(NSView *view) {
    [view drawRect:view.bounds];
    for (NSView *child in view.subviews) {
        if (child.hidden) continue;
        [NSGraphicsContext saveGraphicsState];
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextTranslateCTM(context, child.frame.origin.x, child.frame.origin.y);
        if (child.isFlipped != view.isFlipped) {
            CGContextTranslateCTM(context, 0, child.frame.size.height);
            CGContextScaleCTM(context, 1, -1);
        }
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:child.isFlipped];
        ShiroDrawViewTree(child);
        [NSGraphicsContext restoreGraphicsState];
    }
}
