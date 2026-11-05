#import "TimerModel.h"
#import "TaskModel.h"
#import "LinkedFile.h"
#include <math.h>

static void check(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}
int main(void) {
    @autoreleasepool {
        // Timer: start, pause, resume, finish, manual next phase.
        ShiroTimer *timer = [[ShiroTimer alloc] initWithState:nil now:100];
        check(!timer.running && timer.remaining == 1200 && timer.breakSeconds == 420, @"default 20/7 minutes, paused");
        check(![timer isPartialAt:100], @"fresh interval is not partial");
        [timer startAt:100];
        check([timer remainingAt:130.25] == 1169.75, @"deadline, no tick drift");
        [timer pauseAt:130.25];
        check([timer remainingAt:800] == 1169.75 && [timer isPartialAt:800], @"pause keeps time and shows Resume");
        [timer startAt:1000];
        check([timer tickAt:2169.74] == nil, @"not early");
        check([[timer tickAt:2169.75] isEqual:@"workFinished"], @"focus completion");
        check(!timer.running && [timer.phase isEqual:@"break"] && timer.remaining == 420 && timer.completed == 1, @"break waits for start");
        [timer startAt:3000];
        check([[timer tickAt:3420] isEqual:@"breakFinished"], @"break completion");
        check(!timer.running && [timer.phase isEqual:@"work"] && timer.remaining == 1200, @"next focus waits for start");

        // Switching phases keeps each slot.
        [timer startAt:4000]; [timer pauseAt:4300];
        [timer switchToPhase:@"break" at:4300];
        check([timer.phase isEqual:@"break"] && timer.remaining == 420 && timer.otherRemaining == 900, @"switch to break keeps focus time");
        check([timer workRemainingAt:4300] == 900, @"focus time readable during break");
        [timer startAt:4400]; [timer switchToPhase:@"work" at:4500];
        check(!timer.running && timer.remaining == 900 && timer.otherRemaining == 320, @"switch back pauses break and restores focus");
        [timer reset];
        check(timer.remaining == 1200 && [timer.phase isEqual:@"work"], @"reset current phase to full length");

        // Saved per-task time.
        [timer loadWorkRemaining:500 at:5000];
        check(!timer.running && timer.remaining == 500, @"load task time");
        [timer loadWorkRemaining:-1 at:5000];
        check(timer.remaining == 1200, @"fresh task gets full length");

        // Restore and sleep.
        [timer setWorkMinutes:1 breakMinutes:2];
        check(timer.remaining == 60 && timer.otherRemaining == 120, @"untouched slots follow new lengths");
        [timer startAt:6000];
        ShiroTimer *restored = [[ShiroTimer alloc] initWithState:timer.state now:9000];
        check([[restored tickAt:9000] isEqual:@"workFinished"] && !restored.running, @"late wake-up finishes focus once and waits");
        ShiroTimer *legacy = [[ShiroTimer alloc] initWithState:@{@"phase":@"work", @"remaining":@700, @"workSeconds":@1500, @"breakSeconds":@300} now:0];
        check(legacy.remaining == 700 && legacy.otherRemaining == 300, @"0.5 timer state migrates");
        [legacy setWorkMinutes:NAN breakMinutes:999];
        check(legacy.workSeconds == 1200 && legacy.breakSeconds == 3600, @"invalid duration clamped");

        // Tasks and sections.
        ShiroTaskStore *tasks = [[ShiroTaskStore alloc] initWithState:nil];
        check(tasks.sections.count == 2 && [tasks.sections.firstObject[@"title"] isEqual:@"Работа"], @"default sections");
        NSString *work = tasks.sections[0][@"id"], *personal = tasks.sections[1][@"id"];
        NSString *first = [tasks addTitle:@"  Собрать референсы  " toSectionID:work];
        NSString *second = [tasks addTitle:@"Записать голос" toSectionID:work];
        NSString *third = [tasks addTitle:@"Подготовиться" toSectionID:personal];
        check([[tasks taskWithID:first][@"title"] isEqual:@"Собрать референсы"] && [[tasks taskWithID:third][@"sectionID"] isEqual:personal], @"add to a chosen section");
        check([tasks.activeTaskID isEqual:first], @"first task becomes selected");
        check(![tasks addTitle:@"x" toSectionID:@"missing"], @"unknown section rejected");
        check([tasks toggleTaskID:first], @"complete task");
        NSArray *ordered = [tasks tasksInSectionID:work];
        check([ordered.lastObject[@"id"] isEqual:first] && [ordered.firstObject[@"id"] isEqual:second] && [tasks.doneTasks.firstObject[@"id"] isEqual:first], @"done task keeps its section and goes to the done list");
        check([tasks.activeTaskID isEqual:second], @"selection moves to next open task");
        check(![tasks selectTaskID:first], @"done task cannot be selected");
        check([tasks renameTaskID:second title:@"Записать голос Широ"] && [[tasks taskWithID:second][@"title"] isEqual:@"Записать голос Широ"], @"rename task");
        check([tasks renameSectionID:personal title:@"Дом"] && [[tasks sectionWithID:personal][@"title"] isEqual:@"Дом"], @"rename section");
        [tasks setRemaining:333 forTaskID:third];
        check([tasks remainingForTaskID:third] == 333 && [tasks remainingForTaskID:second] == -1, @"per-task time");
        NSString *home = [tasks addSectionTitle:@"  Проект  "];
        check([[tasks sectionWithID:home][@"title"] isEqual:@"Проект"], @"section title keeps case");
        check([tasks moveSectionID:home toIndex:0] && [tasks.sections.firstObject[@"id"] isEqual:home], @"drag reorder sections");
        [tasks selectTaskID:third];
        check([tasks deleteSectionID:personal] && ![tasks taskWithID:third] && tasks.sections.count == 2, @"delete section with its tasks");
        check([tasks.activeTaskID isEqual:second], @"deleting the selected task's section picks another task");
        [tasks beginFocusAtRemaining:1200];
        [tasks creditThroughRemaining:900 completedPomodoro:NO];
        check([[tasks taskWithID:second][@"focusSeconds"] doubleValue] == 300, @"partial focus credited");
        check([tasks deleteTaskID:second] && tasks.activeTaskID == nil, @"delete last open task clears selection");
        ShiroTaskStore *restoredTasks = [[ShiroTaskStore alloc] initWithState:tasks.state];
        check(restoredTasks.sections.count == 2 && [restoredTasks.sections.firstObject[@"id"] isEqual:home] && restoredTasks.tasks.count == 1, @"restore tasks and section order");

        // 0.5 save: upper-case titles, separate "done" list, no version.
        NSDictionary *old = @{@"sections":@[@{@"id":@"work", @"title":@"РАБОТА", @"collapsed":@NO}, @{@"id":@"personal", @"title":@"ЛИЧНОЕ", @"collapsed":@YES}],
                              @"tasks":@[@{@"id":@"a", @"title":@"Сделать два макета", @"sectionID":@"work", @"done":@NO, @"focusSeconds":@600, @"pomodoros":@1},
                                         @{@"id":@"b", @"title":@"Без раздела", @"done":@YES}],
                              @"activeTaskID":@"a", @"selectedSectionID":@"work", @"focusAnchorRemaining":@(-1)};
        ShiroTaskStore *migrated = [[ShiroTaskStore alloc] initWithState:old];
        check([migrated.sections[0][@"title"] isEqual:@"Работа"] && [migrated.sections[1][@"title"] isEqual:@"Личное"], @"0.5 upper-case titles migrate");
        check(migrated.tasks.count == 2 && [[migrated taskWithID:@"b"][@"sectionID"] isEqual:@"work"] && [[migrated taskWithID:@"a"][@"focusSeconds"] doubleValue] == 600, @"0.5 tasks keep data");
        ShiroTaskStore *again = [[ShiroTaskStore alloc] initWithState:@{@"sections":@[@{@"id":@"x", @"title":@"TODO"}], @"tasks":@[], @"version":@6}];
        check([again.sections[0][@"title"] isEqual:@"TODO"], @"0.6 titles are not rewritten");
        // Reordering, done list, links.
        ShiroTaskStore *order = [[ShiroTaskStore alloc] initWithState:nil];
        NSString *w = order.sections[0][@"id"], *p = order.sections[1][@"id"];
        NSString *t1 = [order addTitle:@"один" toSectionID:w], *t2 = [order addTitle:@"два" toSectionID:w], *t3 = [order addTitle:@"три" toSectionID:w];
        check([order moveTaskID:t3 toSectionID:w beforeTaskID:t1] && [[order openTasksInSectionID:w][0][@"id"] isEqual:t3], @"move task up");
        check([order moveTaskID:t3 toSectionID:w beforeTaskID:nil] && [[order openTasksInSectionID:w].lastObject[@"id"] isEqual:t3], @"move task to the end");
        check([order moveTaskID:t2 toSectionID:p beforeTaskID:nil] && [[order taskWithID:t2][@"sectionID"] isEqual:p], @"move task to another section");
        [order toggleTaskID:t1]; [order toggleTaskID:t3];
        check(order.doneTasks.count == 2 && [order.doneTasks[0][@"id"] isEqual:t3] && [order openTasksInSectionID:w].count == 0, @"done list, newest first");
        check([order moveTaskID:t1 toSectionID:p beforeTaskID:t2] && ![[order taskWithID:t1][@"done"] boolValue] && [[order openTasksInSectionID:p][0][@"id"] isEqual:t1], @"drag back from done list reopens");
        check([order setLink:@" figma.com/file/1 " forTaskID:t2] && [[order taskWithID:t2][@"link"] isEqual:@"figma.com/file/1"], @"attach link");
        ShiroTaskStore *withLink = [[ShiroTaskStore alloc] initWithState:order.state];
        check([[withLink taskWithID:t2][@"link"] isEqual:@"figma.com/file/1"] && withLink.doneCollapsed, @"link and done list state restored");
        check([order setLink:@"" forTaskID:t2] && ![order taskWithID:t2][@"link"], @"remove link");
        check([order clearDone] == 1 && ![order taskWithID:t3], @"clear done list forever");
        // Connected Markdown file, in the format of the daily "Сегодня" note.
        NSString *day = @"# Пример дня\n\n## Утро\n- [x] ⭐ 09:00–09:40 Хобби: посмотреть [пример](https://example.com/demo?item=1), сделать заметку\n- [ ] 10:00–10:15 перерыв\n    - [ ] вложенный пункт\n- [ ] Подготовиться [[Заметка|к прогулке]]\n\nПлан закрыт\n\n## Всплыло за день\n- Простая заметка без флажка\n\n## Итог дня\n- [ ] не показывать\n";
        NSArray<ShiroFileTask *> *fileTasks = [ShiroLinkedFile tasksInText:day filePath:@"/vault/Сегодня.md"];
        check(fileTasks.count == 3, @"file: top-level checkboxes only, summary section hidden");
        check(fileTasks[0].done && [fileTasks[0].title isEqual:@"⭐ 09:00–09:40 Хобби: посмотреть пример, сделать заметку"] && [fileTasks[0].link hasPrefix:@"https://example.com/demo"], @"file: star, time and link text kept, link extracted");
        check([fileTasks[1].section isEqual:@"Утро"] && !fileTasks[1].done, @"file: section names");
        check([fileTasks[2].title isEqual:@"Подготовиться к прогулке"] && [fileTasks[2].link hasPrefix:@"obsidian://open?path="], @"file: wiki link opens Obsidian");
        NSString *added = [ShiroLinkedFile text:day byAppendingTask:@"Полить цветы"];
        check([added containsString:@"- Простая заметка без флажка\n- [ ] Полить цветы\n\n## Итог дня"], @"file: new task goes to the end of «Всплыло за день»");
        check([[added stringByReplacingOccurrencesOfString:@"- [ ] Полить цветы\n" withString:@""] isEqual:day], @"file: nothing else changes");
        NSString *today = @"# Пример дня\n\n## Задачи\n- [ ] Хобби: собрать список\n\n## Всплыло за день\n\n## Итог дня\n";
        check([[ShiroLinkedFile text:today byAppendingTask:@"Новая"] containsString:@"## Всплыло за день\n- [ ] Новая\n\n## Итог дня"], @"file: empty «Всплыло за день» gets the task");
        NSString *plain = @"# Список\n\n## Работа\n- [ ] Раз\n\n## Дом\n- [ ] Два\n";
        check([[ShiroLinkedFile text:plain byAppendingTask:@"Три"] containsString:@"- [ ] Раз\n- [ ] Три\n\n## Дом"], @"file: without «Всплыло за день» the first section gets it");
        check([[ShiroLinkedFile text:@"" byAppendingTask:@"Одна"] isEqual:@"- [ ] Одна\n"], @"file: empty file");
        NSString *marked = [ShiroLinkedFile text:day bySettingTask:fileTasks[1] done:YES];
        check([marked containsString:@"- [x] 10:00–10:15 перерыв"] && [[marked stringByReplacingOccurrencesOfString:@"- [x] 10:00–10:15 перерыв" withString:@"- [ ] 10:00–10:15 перерыв"] isEqual:day], @"file: marking done flips one character only");
        NSString *unmarked = [ShiroLinkedFile text:day bySettingTask:fileTasks[0] done:NO];
        check([unmarked containsString:@"- [ ] ⭐ 09:00–09:40"] && unmarked.length == day.length, @"file: reopening flips it back");
        // Shiro's own order for the file block; the file itself stays as it is.
        NSString *two = @"## План\n- [ ] А\n- [ ] Б\n- [ ] В\n## Всплыло за день\n- [ ] Г\n";
        NSArray<ShiroFileTask *> *parsed = [ShiroLinkedFile tasksInText:two filePath:nil];
        NSArray *shownTitles = [[ShiroLinkedFile tasks:parsed inOrder:@[@"В", @"А"] sections:@{}] valueForKey:@"title"];
        check([shownTitles isEqual:@[@"В", @"А", @"Б", @"Г"]], @"file order: known titles first, new ones at the end of their group");
        NSArray<ShiroFileTask *> *shownTasks = [ShiroLinkedFile tasks:parsed inOrder:@[] sections:@{}];
        NSArray *moved = [ShiroLinkedFile orderAfterMoving:shownTasks[0] before:nil section:@"Всплыло за день" shown:shownTasks];
        check([moved isEqual:@[@"Б", @"В", @"Г", @"А"]], @"file order: move to the end of another group");
        NSArray *regrouped = [ShiroLinkedFile tasks:parsed inOrder:moved sections:@{@"А":@"Всплыло за день"}];
        check([[regrouped valueForKey:@"title"] isEqual:@[@"Б", @"В", @"Г", @"А"]] && [regrouped.lastObject section] && [[regrouped.lastObject section] isEqual:@"Всплыло за день"] && [[regrouped.lastObject rawLine] isEqual:@"- [ ] А"], @"file order: moved task shows in its new group, file line kept");
        NSArray *up = [ShiroLinkedFile orderAfterMoving:shownTasks[2] before:shownTasks[0] section:@"План" shown:shownTasks];
        check([up isEqual:@[@"В", @"А", @"Б", @"Г"]], @"file order: move up");
        ShiroFileTask *gone = [[ShiroFileTask alloc] init]; gone.rawLine = @"- [ ] нет такой";
        check([ShiroLinkedFile text:day bySettingTask:gone done:YES] == nil, @"file: a vanished line is not touched");
        NSLog(@"PASS: timer and checklist checks (phases, per-task time, sections, reorder, done list, links, connected file, migration, restore)");
    }
    return 0;
}
