#import <Foundation/Foundation.h>

// Sections hold open tasks; finished tasks keep their sectionID but are shown together in the "done" list.
// activeTaskID is the selected task. Each task may keep its own focus time ("remaining", -1 means fresh).
@interface ShiroTaskStore : NSObject
@property(nonatomic, readonly) NSArray<NSMutableDictionary *> *tasks;
@property(nonatomic, readonly) NSArray<NSMutableDictionary *> *sections;
@property(nonatomic, copy) NSString *activeTaskID;
@property(nonatomic) double focusAnchorRemaining;
@property(nonatomic) BOOL doneCollapsed;
@property(nonatomic, readonly) NSInteger revision;
- (instancetype)initWithState:(NSDictionary *)state;
- (instancetype)initWithState:(NSDictionary *)state defaultSections:(NSArray<NSString *> *)titles;
- (NSString *)addTitle:(NSString *)title toSectionID:(NSString *)sectionID;
- (NSString *)addSectionTitle:(NSString *)title;
- (NSMutableDictionary *)sectionWithID:(NSString *)sectionID;
- (NSArray<NSMutableDictionary *> *)tasksInSectionID:(NSString *)sectionID;      // open first, then done
- (NSArray<NSMutableDictionary *> *)openTasksInSectionID:(NSString *)sectionID;
- (NSArray<NSMutableDictionary *> *)doneTasks;                                  // most recently finished first
- (void)toggleDoneCollapsed;
- (NSInteger)clearDone;
- (void)toggleSectionID:(NSString *)sectionID;
- (void)expandSectionID:(NSString *)sectionID;
- (BOOL)renameSectionID:(NSString *)sectionID title:(NSString *)title;
- (BOOL)deleteSectionID:(NSString *)sectionID;
- (BOOL)moveSectionID:(NSString *)sectionID toIndex:(NSInteger)index;
- (NSMutableDictionary *)taskWithID:(NSString *)taskID;
- (NSMutableDictionary *)firstOpenTask;
- (BOOL)toggleTaskID:(NSString *)taskID;
- (BOOL)renameTaskID:(NSString *)taskID title:(NSString *)title;
- (BOOL)deleteTaskID:(NSString *)taskID;
// Puts a task before another open task of a section (nil: at the end of its open tasks); a finished task is reopened.
- (BOOL)moveTaskID:(NSString *)taskID toSectionID:(NSString *)sectionID beforeTaskID:(NSString *)beforeID;
- (BOOL)setLink:(NSString *)link forTaskID:(NSString *)taskID;   // empty removes the link
- (BOOL)selectTaskID:(NSString *)taskID;
- (double)remainingForTaskID:(NSString *)taskID;
- (void)setRemaining:(double)remaining forTaskID:(NSString *)taskID;
- (void)resetAllRemaining;
- (void)beginFocusAtRemaining:(double)remaining;
- (void)creditThroughRemaining:(double)remaining completedPomodoro:(BOOL)completed;
- (NSDictionary *)state;
@end
