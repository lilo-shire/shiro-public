#import "TaskModel.h"
#include <math.h>

static NSString *Trimmed(id value, NSUInteger limit) {
    NSString *text = [value isKindOfClass:NSString.class] ? value : @"";
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return text.length > limit ? [text substringToIndex:limit] : text;
}

// Version 0.5 forced section titles to upper case; show them as normal words again.
static NSString *SectionTitleFromLegacy(NSString *title) {
    if (![title isEqual:title.uppercaseString] || [title isEqual:title.lowercaseString]) return title;
    NSString *lower = title.lowercaseString;
    return [[lower substringToIndex:1].uppercaseString stringByAppendingString:[lower substringFromIndex:1]];
}

@interface ShiroTaskStore ()
@property(nonatomic) NSMutableArray<NSMutableDictionary *> *mutableTasks;
@property(nonatomic) NSMutableArray<NSMutableDictionary *> *mutableSections;
@property(nonatomic) NSInteger mutableRevision;
@end

@implementation ShiroTaskStore
- (instancetype)initWithState:(NSDictionary *)state {
    return [self initWithState:state defaultSections:@[@"Работа", @"Личное"]];
}
- (instancetype)initWithState:(NSDictionary *)state defaultSections:(NSArray<NSString *> *)titles {
    if (!(self = [super init])) return nil;
    _mutableTasks = [NSMutableArray array];
    _mutableSections = [NSMutableArray array];
    NSArray *savedSections = [state[@"sections"] isKindOfClass:NSArray.class] ? state[@"sections"] : @[];
    BOOL legacy = [state[@"version"] integerValue] < 6;
    for (id value in savedSections) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        NSString *title = Trimmed(value[@"title"], 32);
        if (!title.length) continue;
        NSString *sectionID = [value[@"id"] isKindOfClass:NSString.class] ? value[@"id"] : NSUUID.UUID.UUIDString;
        [_mutableSections addObject:[@{@"id":sectionID, @"title":legacy ? SectionTitleFromLegacy(title) : title, @"collapsed":@([value[@"collapsed"] boolValue])} mutableCopy]];
        if (_mutableSections.count == 24) break;
    }
    if (!_mutableSections.count && !state[@"sections"]) {
        NSArray *ids = @[@"work", @"personal"];
        for (NSUInteger i = 0; i < titles.count && i < 24; i++)
            [_mutableSections addObject:[@{@"id":i < ids.count ? ids[i] : NSUUID.UUID.UUIDString, @"title":Trimmed(titles[i], 32), @"collapsed":@NO} mutableCopy]];
    }
    NSArray *saved = [state[@"tasks"] isKindOfClass:NSArray.class] ? state[@"tasks"] : @[];
    for (id value in saved) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        NSString *title = Trimmed(value[@"title"], 100);
        if (!title.length) continue;
        NSString *sectionID = [value[@"sectionID"] isKindOfClass:NSString.class] ? value[@"sectionID"] : nil;
        if (![self sectionWithID:sectionID]) {
            // A task without a section gets the first one; with no sections at all a "Задачи" section is created.
            if (!_mutableSections.count) [_mutableSections addObject:[@{@"id":NSUUID.UUID.UUIDString, @"title":@"Задачи", @"collapsed":@NO} mutableCopy]];
            sectionID = _mutableSections.firstObject[@"id"];
        }
        NSString *taskID = [value[@"id"] isKindOfClass:NSString.class] ? value[@"id"] : NSUUID.UUID.UUIDString;
        double focus = [value[@"focusSeconds"] doubleValue];
        double remaining = value[@"remaining"] ? [value[@"remaining"] doubleValue] : -1;
        NSInteger pomodoros = [value[@"pomodoros"] integerValue];
        NSMutableDictionary *task = [@{@"id":taskID, @"title":title, @"sectionID":sectionID, @"done":@([value[@"done"] boolValue]),
                                       @"focusSeconds":@(isfinite(focus) ? MAX(0, focus) : 0), @"pomodoros":@(MAX(0, pomodoros)),
                                       @"remaining":@(isfinite(remaining) && remaining > 0 ? remaining : -1)} mutableCopy];
        NSString *link = Trimmed(value[@"link"], 2000);
        if (link.length) task[@"link"] = link;
        [_mutableTasks addObject:task];
        if (_mutableTasks.count == 200) break;
    }
    NSString *active = [state[@"activeTaskID"] isKindOfClass:NSString.class] ? state[@"activeTaskID"] : nil;
    NSMutableDictionary *activeTask = [self taskWithID:active];
    _activeTaskID = activeTask && ![activeTask[@"done"] boolValue] ? [active copy] : [self.firstOpenTask[@"id"] copy];
    double anchor = [state[@"focusAnchorRemaining"] doubleValue];
    _focusAnchorRemaining = state[@"focusAnchorRemaining"] && isfinite(anchor) && anchor >= 0 ? anchor : -1;
    _doneCollapsed = state[@"doneCollapsed"] ? [state[@"doneCollapsed"] boolValue] : YES;
    return self;
}
- (NSArray *)tasks { return self.mutableTasks; }
- (NSArray *)sections { return self.mutableSections; }
- (NSInteger)revision { return self.mutableRevision; }
- (void)changed { self.mutableRevision++; }

- (NSString *)addTitle:(NSString *)title toSectionID:(NSString *)sectionID {
    title = Trimmed(title, 100);
    if (!title.length || self.mutableTasks.count >= 200 || ![self sectionWithID:sectionID]) return nil;
    NSString *taskID = NSUUID.UUID.UUIDString;
    [self.mutableTasks addObject:[@{@"id":taskID, @"title":title, @"sectionID":sectionID, @"done":@NO,
                                    @"focusSeconds":@0, @"pomodoros":@0, @"remaining":@(-1)} mutableCopy]];
    if (!self.activeTaskID) self.activeTaskID = taskID;
    [self changed]; return taskID;
}
- (NSString *)addSectionTitle:(NSString *)title {
    title = Trimmed(title, 32);
    if (!title.length || self.mutableSections.count >= 24) return nil;
    NSString *sectionID = NSUUID.UUID.UUIDString;
    [self.mutableSections addObject:[@{@"id":sectionID, @"title":title, @"collapsed":@NO} mutableCopy]];
    [self changed]; return sectionID;
}
- (NSMutableDictionary *)sectionWithID:(NSString *)sectionID {
    if (!sectionID) return nil;
    for (NSMutableDictionary *section in self.mutableSections) if ([section[@"id"] isEqual:sectionID]) return section;
    return nil;
}
- (NSArray<NSMutableDictionary *> *)tasksInSectionID:(NSString *)sectionID {
    NSMutableArray *open = [NSMutableArray array], *done = [NSMutableArray array];
    for (NSMutableDictionary *task in self.mutableTasks)
        if ([task[@"sectionID"] isEqual:sectionID]) [[task[@"done"] boolValue] ? done : open addObject:task];
    [open addObjectsFromArray:done];
    return open;
}
- (NSArray<NSMutableDictionary *> *)openTasksInSectionID:(NSString *)sectionID {
    NSMutableArray *open = [NSMutableArray array];
    for (NSMutableDictionary *task in self.mutableTasks)
        if ([task[@"sectionID"] isEqual:sectionID] && ![task[@"done"] boolValue]) [open addObject:task];
    return open;
}
- (NSArray<NSMutableDictionary *> *)doneTasks {
    NSMutableArray *done = [NSMutableArray array];
    for (NSMutableDictionary *task in self.mutableTasks.reverseObjectEnumerator) if ([task[@"done"] boolValue]) [done addObject:task];
    return done;
}
- (void)toggleDoneCollapsed { self.doneCollapsed = !self.doneCollapsed; [self changed]; }
- (NSInteger)clearDone {
    NSInteger before = (NSInteger)self.mutableTasks.count;
    [self.mutableTasks filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *task, NSDictionary *_) { return ![task[@"done"] boolValue]; }]];
    NSInteger removed = before - (NSInteger)self.mutableTasks.count;
    if (removed) [self changed];
    return removed;
}
- (void)toggleSectionID:(NSString *)sectionID {
    NSMutableDictionary *section = [self sectionWithID:sectionID]; if (!section) return;
    section[@"collapsed"] = @(![section[@"collapsed"] boolValue]); [self changed];
}
- (void)expandSectionID:(NSString *)sectionID {
    NSMutableDictionary *section = [self sectionWithID:sectionID];
    if (!section || ![section[@"collapsed"] boolValue]) return;
    section[@"collapsed"] = @NO; [self changed];
}
- (BOOL)renameSectionID:(NSString *)sectionID title:(NSString *)title {
    NSMutableDictionary *section = [self sectionWithID:sectionID];
    title = Trimmed(title, 32);
    if (!section || !title.length) return NO;
    section[@"title"] = title; [self changed]; return YES;
}
- (BOOL)deleteSectionID:(NSString *)sectionID {
    NSMutableDictionary *section = [self sectionWithID:sectionID]; if (!section) return NO;
    BOOL hadActive = [[self taskWithID:self.activeTaskID][@"sectionID"] isEqual:sectionID];
    [self.mutableTasks filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *task, NSDictionary *_) {
        return ![task[@"sectionID"] isEqual:sectionID];
    }]];
    [self.mutableSections removeObject:section];
    if (hadActive) { self.activeTaskID = self.firstOpenTask[@"id"]; self.focusAnchorRemaining = -1; }
    [self changed]; return YES;
}
- (BOOL)moveSectionID:(NSString *)sectionID toIndex:(NSInteger)index {
    NSMutableDictionary *section = [self sectionWithID:sectionID];
    if (!section || self.mutableSections.count < 2) return NO;
    NSInteger oldIndex = [self.mutableSections indexOfObjectIdenticalTo:section];
    NSInteger nextIndex = MAX(0, MIN(index, (NSInteger)self.mutableSections.count - 1));
    if (oldIndex == nextIndex) return NO;
    [self.mutableSections removeObjectAtIndex:oldIndex];
    [self.mutableSections insertObject:section atIndex:nextIndex];
    [self changed]; return YES;
}
- (NSMutableDictionary *)taskWithID:(NSString *)taskID {
    if (!taskID) return nil;
    for (NSMutableDictionary *task in self.mutableTasks) if ([task[@"id"] isEqual:taskID]) return task;
    return nil;
}
- (NSMutableDictionary *)firstOpenTask {
    for (NSDictionary *section in self.mutableSections) {
        NSMutableDictionary *task = [self openTasksInSectionID:section[@"id"]].firstObject;
        if (task) return task;
    }
    return nil;
}
- (BOOL)toggleTaskID:(NSString *)taskID {
    NSMutableDictionary *task = [self taskWithID:taskID]; if (!task) return NO;
    BOOL done = ![task[@"done"] boolValue]; task[@"done"] = @(done);
    // Moving the task to the end puts it last in its group: last finished, or last reopened.
    [self.mutableTasks removeObjectIdenticalTo:task]; [self.mutableTasks addObject:task];
    if (done && [self.activeTaskID isEqual:taskID]) { self.activeTaskID = self.firstOpenTask[@"id"]; self.focusAnchorRemaining = -1; }
    if (!done && !self.activeTaskID) self.activeTaskID = taskID;
    [self changed]; return done;
}
- (BOOL)renameTaskID:(NSString *)taskID title:(NSString *)title {
    NSMutableDictionary *task = [self taskWithID:taskID];
    title = Trimmed(title, 100);
    if (!task || !title.length) return NO;
    task[@"title"] = title; [self changed]; return YES;
}
- (BOOL)deleteTaskID:(NSString *)taskID {
    NSMutableDictionary *task = [self taskWithID:taskID]; if (!task) return NO;
    BOOL active = [self.activeTaskID isEqual:taskID];
    [self.mutableTasks removeObject:task];
    if (active) { self.activeTaskID = self.firstOpenTask[@"id"]; self.focusAnchorRemaining = -1; }
    [self changed]; return YES;
}
- (BOOL)moveTaskID:(NSString *)taskID toSectionID:(NSString *)sectionID beforeTaskID:(NSString *)beforeID {
    NSMutableDictionary *task = [self taskWithID:taskID];
    if (!task || ![self sectionWithID:sectionID] || [beforeID isEqual:taskID]) return NO;
    BOOL reopened = [task[@"done"] boolValue];
    [self.mutableTasks removeObjectIdenticalTo:task];
    task[@"sectionID"] = sectionID; task[@"done"] = @NO;
    NSMutableDictionary *before = [self taskWithID:beforeID];
    NSUInteger index;
    if (before && [before[@"sectionID"] isEqual:sectionID] && ![before[@"done"] boolValue]) index = [self.mutableTasks indexOfObjectIdenticalTo:before];
    else {
        NSMutableDictionary *last = [self openTasksInSectionID:sectionID].lastObject;
        index = last ? [self.mutableTasks indexOfObjectIdenticalTo:last] + 1 : self.mutableTasks.count;
    }
    [self.mutableTasks insertObject:task atIndex:index];
    if (reopened && !self.activeTaskID) self.activeTaskID = taskID;
    [self changed]; return YES;
}
- (BOOL)setLink:(NSString *)link forTaskID:(NSString *)taskID {
    NSMutableDictionary *task = [self taskWithID:taskID]; if (!task) return NO;
    link = Trimmed(link, 2000);
    if (link.length) task[@"link"] = link; else [task removeObjectForKey:@"link"];
    [self changed]; return YES;
}
- (BOOL)selectTaskID:(NSString *)taskID {
    NSMutableDictionary *task = [self taskWithID:taskID];
    if (!task || [task[@"done"] boolValue] || [self.activeTaskID isEqual:taskID]) return NO;
    self.activeTaskID = taskID; self.focusAnchorRemaining = -1;
    [self changed]; return YES;
}
- (double)remainingForTaskID:(NSString *)taskID {
    NSNumber *value = [self taskWithID:taskID][@"remaining"];
    return value ? value.doubleValue : -1;
}
- (void)setRemaining:(double)remaining forTaskID:(NSString *)taskID {
    NSMutableDictionary *task = [self taskWithID:taskID]; if (!task) return;
    task[@"remaining"] = @(isfinite(remaining) && remaining > 0 ? remaining : -1);
}
- (void)resetAllRemaining {
    for (NSMutableDictionary *task in self.mutableTasks) task[@"remaining"] = @(-1);
    [self changed];
}
- (void)beginFocusAtRemaining:(double)remaining { self.focusAnchorRemaining = isfinite(remaining) ? MAX(0, remaining) : -1; }
- (void)creditThroughRemaining:(double)remaining completedPomodoro:(BOOL)completed {
    NSMutableDictionary *task = [self taskWithID:self.activeTaskID];
    if (!task || self.focusAnchorRemaining < 0 || !isfinite(remaining)) return;
    double elapsed = MAX(0, self.focusAnchorRemaining - MAX(0, remaining));
    if (elapsed > 0.01) task[@"focusSeconds"] = @([task[@"focusSeconds"] doubleValue] + elapsed);
    if (completed) task[@"pomodoros"] = @([task[@"pomodoros"] integerValue] + 1);
    self.focusAnchorRemaining = MAX(0, remaining); [self changed];
}
- (NSDictionary *)state {
    return @{@"tasks":self.mutableTasks, @"sections":self.mutableSections, @"activeTaskID":self.activeTaskID ?: @"",
             @"focusAnchorRemaining":@(self.focusAnchorRemaining), @"doneCollapsed":@(self.doneCollapsed), @"version":@6};
}
@end
