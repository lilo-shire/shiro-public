#import "LinkedFile.h"

@implementation ShiroFileTask @end

// Sections Shiro does not show: the day summary is not a list of tasks.
static BOOL HiddenSection(NSString *name) {
    NSString *lower = name.lowercaseString;
    for (NSString *hidden in @[@"итог дня", @"day summary"]) if ([lower hasPrefix:hidden]) return YES;
    return NO;
}
static NSString *HeadingTitle(NSString *line, NSInteger *level) {
    NSInteger hashes = 0;
    while (hashes < (NSInteger)line.length && [line characterAtIndex:hashes] == '#') hashes++;
    if (hashes == 0 || hashes > 6 || (NSInteger)line.length <= hashes || [line characterAtIndex:hashes] != ' ') return nil;
    if (level) *level = hashes;
    return [[line substringFromIndex:hashes] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

@implementation ShiroLinkedFile
+ (NSArray<ShiroFileTask *> *)tasksInText:(NSString *)text filePath:(NSString *)path {
    NSMutableArray *tasks = [NSMutableArray array];
    NSRegularExpression *taskLine = [NSRegularExpression regularExpressionWithPattern:@"^[-*+] \\[([ xX])\\] (.+)$" options:0 error:nil];
    NSRegularExpression *mdLink = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^)\\s]+)\\)" options:0 error:nil];
    NSRegularExpression *wiki = [NSRegularExpression regularExpressionWithPattern:@"\\[\\[([^\\]|]+)(?:\\|([^\\]]+))?\\]\\]" options:0 error:nil];
    NSRegularExpression *bare = [NSRegularExpression regularExpressionWithPattern:@"https?://\\S+" options:0 error:nil];
    NSString *section = @"";
    BOOL hidden = NO;
    for (NSString *raw in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSInteger level = 0;
        NSString *heading = HeadingTitle(raw, &level);
        if (heading) {
            if (level >= 2) { section = heading; hidden = HiddenSection(heading); }
            continue;
        }
        if (hidden) continue;
        // Only top-level checkboxes; indented sub-items stay in the file untouched.
        NSTextCheckingResult *m = [taskLine firstMatchInString:raw options:0 range:NSMakeRange(0, raw.length)];
        if (!m) continue;
        NSString *body = [[raw substringWithRange:[m rangeAtIndex:2]] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *link = nil;
        NSTextCheckingResult *first = [mdLink firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
        if (first) link = [body substringWithRange:[first rangeAtIndex:2]];
        NSTextCheckingResult *note = [wiki firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
        if (!link && note && path.length) {
            // Opens the note in Obsidian; Obsidian resolves the name inside the vault.
            NSString *vaultPath = path.stringByDeletingLastPathComponent;
            NSString *target = [vaultPath stringByAppendingPathComponent:[[body substringWithRange:[note rangeAtIndex:1]] stringByAppendingString:@".md"]];
            NSString *encoded = [target stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
            link = [@"obsidian://open?path=" stringByAppendingString:[encoded stringByReplacingOccurrencesOfString:@"&" withString:@"%26"]];
        }
        if (!link) {
            NSTextCheckingResult *url = [bare firstMatchInString:body options:0 range:NSMakeRange(0, body.length)];
            if (url) link = [body substringWithRange:url.range];
        }
        NSString *title = [mdLink stringByReplacingMatchesInString:body options:0 range:NSMakeRange(0, body.length) withTemplate:@"$1"];
        NSMutableString *plain = [title mutableCopy];
        for (NSTextCheckingResult *w in [wiki matchesInString:title options:0 range:NSMakeRange(0, title.length)].reverseObjectEnumerator) {
            NSRange shown = [w rangeAtIndex:2].location != NSNotFound ? [w rangeAtIndex:2] : [w rangeAtIndex:1];
            [plain replaceCharactersInRange:w.range withString:[title substringWithRange:shown]];
        }
        ShiroFileTask *task = [[ShiroFileTask alloc] init];
        task.section = section; task.title = plain; task.link = link;
        task.done = ![[raw substringWithRange:[m rangeAtIndex:1]] isEqual:@" "];
        task.rawLine = raw;
        [tasks addObject:task];
    }
    return tasks;
}

+ (NSArray<ShiroFileTask *> *)tasks:(NSArray<ShiroFileTask *> *)tasks inOrder:(NSArray<NSString *> *)order sections:(NSDictionary<NSString *, NSString *> *)sections {
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    for (ShiroFileTask *t in tasks) if (![groups containsObject:t.section]) [groups addObject:t.section];
    NSMutableArray *shown = [NSMutableArray array];
    for (NSString *group in groups) {
        NSMutableArray *members = [NSMutableArray array];
        for (NSUInteger i = 0; i < tasks.count; i++) {
            ShiroFileTask *t = tasks[i];
            NSString *moved = sections[t.title];
            NSString *place = moved && [groups containsObject:moved] ? moved : t.section;
            if (![place isEqual:group]) continue;
            ShiroFileTask *copy = [[ShiroFileTask alloc] init];
            copy.section = place; copy.title = t.title; copy.link = t.link; copy.done = t.done; copy.rawLine = t.rawLine;
            NSUInteger known = [order indexOfObject:t.title];
            [members addObject:@[@(known == NSNotFound ? 1000000 + i : known), copy]];
        }
        [members sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [a[0] compare:b[0]]; }];
        for (NSArray *m in members) [shown addObject:m[1]];
    }
    return shown;
}
+ (NSArray<NSString *> *)orderAfterMoving:(ShiroFileTask *)moved before:(ShiroFileTask *)before section:(NSString *)section shown:(NSArray<ShiroFileTask *> *)shown {
    NSMutableArray<ShiroFileTask *> *list = [shown mutableCopy];
    [list removeObjectIdenticalTo:moved];
    NSUInteger index = before ? [list indexOfObjectIdenticalTo:before] : NSNotFound;
    if (index == NSNotFound) {
        index = list.count;
        for (NSUInteger i = 0; i < list.count; i++) if ([list[i].section isEqual:section]) index = i + 1;
    }
    [list insertObject:moved atIndex:index];
    NSMutableArray *titles = [NSMutableArray array];
    for (ShiroFileTask *t in list) [titles addObject:t.title];
    return titles;
}
+ (NSString *)text:(NSString *)text bySettingTask:(ShiroFileTask *)task done:(BOOL)done {
    if (!task.rawLine.length) return nil;
    NSString *newline = [text containsString:@"\r\n"] ? @"\r\n" : @"\n";
    NSMutableArray<NSString *> *lines = [[text componentsSeparatedByString:newline] mutableCopy];
    for (NSUInteger i = 0; i < lines.count; i++) {
        if (![lines[i] isEqual:task.rawLine]) continue;
        // "- [ ] …": the mark is the fourth character.
        if (lines[i].length < 5) return nil;
        lines[i] = [lines[i] stringByReplacingCharactersInRange:NSMakeRange(3, 1) withString:done ? @"x" : @" "];
        return [lines componentsJoinedByString:newline];
    }
    return nil;
}
+ (NSString *)text:(NSString *)text byAppendingTask:(NSString *)title {
    title = [[title componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] componentsJoinedByString:@" "];
    title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!title.length) return text;
    NSString *newline = [text containsString:@"\r\n"] ? @"\r\n" : @"\n";
    NSMutableArray<NSString *> *lines = [[text componentsSeparatedByString:newline] mutableCopy];
    NSInteger target = -1, first = -1;
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        NSInteger level = 0;
        NSString *heading = HeadingTitle(lines[i], &level);
        if (!heading || level < 2) continue;
        if (first < 0) first = i;
        if ([heading.lowercaseString hasPrefix:@"всплыло за день"]) { target = i; break; }
    }
    if (target < 0) target = first;
    NSString *entry = [@"- [ ] " stringByAppendingString:title];
    if (target < 0) {
        // No sections: add at the end of the file.
        while (lines.count && ![lines.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) [lines removeLastObject];
        [lines addObject:entry]; [lines addObject:@""];
        return [lines componentsJoinedByString:newline];
    }
    NSInteger end = (NSInteger)lines.count;
    for (NSInteger i = target + 1; i < (NSInteger)lines.count; i++) if (HeadingTitle(lines[i], NULL)) { end = i; break; }
    NSInteger insert = target + 1;
    for (NSInteger i = target + 1; i < end; i++) if ([lines[i] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) insert = i + 1;
    [lines insertObject:entry atIndex:insert];
    // Keep one blank line before the next heading, as in the original layout.
    if (insert + 1 < (NSInteger)lines.count && HeadingTitle(lines[insert + 1], NULL)) [lines insertObject:@"" atIndex:insert + 1];
    return [lines componentsJoinedByString:newline];
}
@end
