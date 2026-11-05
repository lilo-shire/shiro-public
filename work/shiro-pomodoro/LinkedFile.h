#import <Foundation/Foundation.h>

// A task line read from a connected Markdown file ("- [ ] text" under "## Section").
@interface ShiroFileTask : NSObject
@property(nonatomic, copy) NSString *section;   // "" before the first "##"
@property(nonatomic, copy) NSString *title;     // what Shiro shows: [text](url) → text, [[note]] → note; ⭐ and times are kept
@property(nonatomic, copy) NSString *link;      // first link of the line, or nil
@property(nonatomic) BOOL done;
@property(nonatomic, copy) NSString *rawLine;   // the line as it is in the file, used to find it again
@end

// Shiro reads the file, appends new "- [ ] text" lines and flips "[ ]" ↔ "[x]" of one task; nothing else is changed or removed.
@interface ShiroLinkedFile : NSObject
+ (NSArray<ShiroFileTask *> *)tasksInText:(NSString *)text filePath:(NSString *)path;
// New task goes to the end of "## Всплыло за день" if the file has it, otherwise to the end of the first "##" section.
+ (NSString *)text:(NSString *)text byAppendingTask:(NSString *)title;
// Returns nil when the task line is no longer in the file.
+ (NSString *)text:(NSString *)text bySettingTask:(ShiroFileTask *)task done:(BOOL)done;
// Shiro's own order for the file block, kept outside the file. order lists titles; sections maps a title to the group it was moved to.
// Groups keep the file's order; inside a group known titles follow `order`, new ones go to the end.
+ (NSArray<ShiroFileTask *> *)tasks:(NSArray<ShiroFileTask *> *)tasks inOrder:(NSArray<NSString *> *)order sections:(NSDictionary<NSString *, NSString *> *)sections;
// The new title order after moving `moved` before `before` (nil: to the end of `section`) in the shown list.
+ (NSArray<NSString *> *)orderAfterMoving:(ShiroFileTask *)moved before:(ShiroFileTask *)before section:(NSString *)section shown:(NSArray<ShiroFileTask *> *)shown;
@end
