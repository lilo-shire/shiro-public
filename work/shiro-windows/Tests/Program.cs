using Shiro;
using System.Text.Json;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;

int checks = 0;
void Check(bool value, string name) { if (!value) throw new Exception("FAIL: " + name); checks++; }

// Timer: start, pause, resume, finish, manual next phase.
var timer = new TimerModel();
Check(!timer.State.Running && timer.State.Remaining == 1200 && timer.State.BreakSeconds == 420, "default 20/7 minutes, paused");
Check(!timer.IsPartialAt(100), "fresh interval is not partial");
timer.Start(100);
Check(timer.RemainingAt(130.25) == 1169.75, "deadline, no tick drift");
timer.Pause(130.25);
Check(timer.RemainingAt(800) == 1169.75 && timer.IsPartialAt(800), "pause keeps time and shows Resume");
timer.Start(1000);
Check(timer.Tick(2169.74) == null, "not early");
Check(timer.Tick(2169.75) == "workFinished", "focus completion");
Check(!timer.State.Running && timer.State.Phase == "break" && timer.State.Remaining == 420 && timer.State.Completed == 1, "break waits for start");
timer.Start(3000);
Check(timer.Tick(3420) == "breakFinished", "break completion");
Check(!timer.State.Running && timer.State.Phase == "work" && timer.State.Remaining == 1200, "next focus waits for start");
timer.Start(4000); timer.Pause(4300);
timer.SwitchTo("break", 4300);
Check(timer.State.Phase == "break" && timer.State.Remaining == 420 && timer.State.OtherRemaining == 900, "switch to break keeps focus time");
Check(timer.WorkRemainingAt(4300) == 900, "focus time readable during break");
timer.Start(4400); timer.SwitchTo("work", 4500);
Check(!timer.State.Running && timer.State.Remaining == 900 && timer.State.OtherRemaining == 320, "switch back pauses break and restores focus");
timer.Reset();
Check(timer.State.Remaining == 1200 && timer.State.Phase == "work", "reset current phase to full length");
timer.LoadWorkRemaining(500, 5000);
Check(!timer.State.Running && timer.State.Remaining == 500, "load task time");
timer.LoadWorkRemaining(-1, 5000);
Check(timer.State.Remaining == 1200, "fresh task gets full length");
timer.SetMinutes(1, 2);
Check(timer.State.Remaining == 60 && timer.State.OtherRemaining == 120, "untouched slots follow new lengths");
timer.Start(6000);
var restored = new TimerModel(JsonSerializer.Deserialize<TimerState>(JsonSerializer.Serialize(timer.State)));
Check(restored.Tick(9000) == "workFinished" && !restored.State.Running, "late wake-up finishes focus once and waits");
timer.SetMinutes(double.NaN, 999);
Check(timer.State.WorkSeconds == 1200 && timer.State.BreakSeconds == 3600, "invalid duration clamped");

// Tasks and sections.
var tasks = new TaskStore(null);
Check(tasks.Sections.Count == 2 && tasks.Sections[0].Title == "Работа", "default sections");
string work = tasks.Sections[0].Id, personal = tasks.Sections[1].Id;
string first = tasks.Add("  Собрать референсы  ", work)!, second = tasks.Add("Записать голос", work)!, third = tasks.Add("Подготовиться", personal)!;
Check(tasks.Task(first)!.Title == "Собрать референсы" && tasks.Task(third)!.SectionId == personal, "add to a chosen section");
Check(tasks.ActiveTaskId == first, "first task becomes selected");
Check(tasks.Add("x", "missing") == null, "unknown section rejected");
Check(tasks.Toggle(first), "complete task");
Check(tasks.InSection(work).Last().Id == first && tasks.DoneTasks()[0].Id == first, "done task keeps its section and goes to the done list");
Check(tasks.ActiveTaskId == second && !tasks.Select(first), "selection moves on; done task cannot be selected");
Check(tasks.Rename(second, "Записать голос Широ") && tasks.RenameSection(personal, "Дом"), "rename task and section");
tasks.SetRemaining(third, 333);
Check(tasks.RemainingOf(third) == 333 && tasks.RemainingOf(second) == -1, "per-task time");
string project = tasks.AddSection("  Проект  ")!;
Check(tasks.Section(project)!.Title == "Проект" && tasks.MoveSection(project, 0) && tasks.Sections[0].Id == project, "section title keeps case; reorder");
tasks.Select(third);
Check(tasks.DeleteSection(personal) && tasks.Task(third) == null && tasks.ActiveTaskId == second, "delete section with its tasks");
tasks.BeginFocus(1200); tasks.Credit(900, false);
Check(tasks.Task(second)!.FocusSeconds == 300, "partial focus credited");
string a = tasks.Add("один", work)!, b = tasks.Add("два", work)!;
Check(tasks.Move(b, work, second) && tasks.OpenIn(work)[0].Id == b, "move task up");
Check(tasks.Move(b, project, null) && tasks.Task(b)!.SectionId == project, "move task to another section");
Check(tasks.Move(first, project, b) && !tasks.Task(first)!.Done && tasks.OpenIn(project)[0].Id == first, "drag back from done list reopens");
Check(tasks.SetLink(a, " figma.com/file/1 ") && tasks.Task(a)!.Link == "figma.com/file/1", "attach link");
tasks.Toggle(a);
var again = new TaskStore(JsonSerializer.Deserialize<TaskState>(JsonSerializer.Serialize(tasks.State)));
Check(again.Task(a)!.Link == "figma.com/file/1" && again.Sections[0].Id == project && again.DoneCollapsed, "restore tasks, links, order");
Check(tasks.ClearDone() == 1 && tasks.Task(a) == null, "clear done list forever");
var keep = new TaskStore(new TaskState { Sections = new() { new() { Id = "x", Title = "TODO" } } });
Check(keep.Sections[0].Title == "TODO", "0.6 titles are not rewritten");

// 0.5 save: flat object, upper-case titles.
string old = "{\"Phase\":\"work\",\"WorkSeconds\":1500,\"BreakSeconds\":300,\"Remaining\":700,\"Sound\":false,\"X\":10,\"Y\":20," +
             "\"Sections\":[{\"Id\":\"work\",\"Title\":\"РАБОТА\"},{\"Id\":\"personal\",\"Title\":\"ЛИЧНОЕ\",\"Collapsed\":true}]," +
             "\"Tasks\":[{\"Id\":\"t\",\"Title\":\"Сделать два макета\",\"SectionId\":\"work\",\"FocusSeconds\":600,\"Pomodoros\":1}],\"ActiveTaskId\":\"t\"}";
var migrated = AppState.Load(old);
var migratedTimer = new TimerModel(migrated.Timer);
var migratedTasks = new TaskStore(migrated.Checklist);
Check(migratedTimer.State.Remaining == 700 && migratedTimer.State.OtherRemaining == 300 && migrated.X == 10, "0.5 timer and position migrate");
Check(migratedTasks.Sections[0].Title == "Работа" && migratedTasks.Sections[1].Title == "Личное" && migratedTasks.Task("t")!.FocusSeconds == 600, "0.5 tasks migrate");
var round = AppState.Load(JsonSerializer.Serialize(new AppState { Theme = "shiro", Checklist = migratedTasks.State }));
Check(round.Theme == "shiro" && new TaskStore(round.Checklist).Sections[0].Title == "Работа", "0.6 state round trip");

// Connected Markdown file.
string day = "# Пример дня\n\n## Утро\n- [x] ⭐ 09:00–09:40 Хобби: посмотреть [пример](https://example.com/demo?item=1), сделать заметку\n- [ ] 10:00–10:15 перерыв\n    - [ ] вложенный пункт\n- [ ] Подготовиться [[Заметка|к прогулке]]\n\nПлан закрыт\n\n## Всплыло за день\n- Простая заметка без флажка\n\n## Итог дня\n- [ ] не показывать\n";
var fileTasks = LinkedFile.Parse(day, "/vault/Сегодня.md");
Check(fileTasks.Count == 3, "file: top-level checkboxes only, summary section hidden");
Check(fileTasks[0].Done && fileTasks[0].Title == "⭐ 09:00–09:40 Хобби: посмотреть пример, сделать заметку" && fileTasks[0].Link!.StartsWith("https://example.com/demo"), "file: star, time and link kept");
Check(fileTasks[1].Section == "Утро" && !fileTasks[1].Done, "file: section names");
Check(fileTasks[2].Title == "Подготовиться к прогулке" && fileTasks[2].Link!.StartsWith("obsidian://open?path="), "file: wiki link opens Obsidian");
string added = LinkedFile.Append(day, "Полить цветы");
Check(added.Contains("- Простая заметка без флажка\n- [ ] Полить цветы\n\n## Итог дня") && added.Replace("- [ ] Полить цветы\n", "") == day, "file: append only one line to «Всплыло за день»");
Check(LinkedFile.Append("# Список\n\n## Работа\n- [ ] Раз\n\n## Дом\n- [ ] Два\n", "Три").Contains("- [ ] Раз\n- [ ] Три\n\n## Дом"), "file: first section without «Всплыло за день»");
Check(LinkedFile.Append("", "Одна") == "- [ ] Одна\n", "file: empty file");
string marked = LinkedFile.SetDone(day, fileTasks[1], true)!;
Check(marked.Contains("- [x] 10:00–10:15 перерыв") && marked.Length == day.Length, "file: marking flips one character");
Check(LinkedFile.SetDone(day, new FileTask { RawLine = "- [ ] нет такой" }, true) == null, "file: vanished line untouched");
string crlf = day.Replace("\n", "\r\n");
Check(LinkedFile.SetDone(crlf, LinkedFile.Parse(crlf, null)[1], true)!.Contains("- [x] 10:00–10:15 перерыв\r\n"), "file: Windows line endings kept");
var parsed = LinkedFile.Parse("## План\n- [ ] А\n- [ ] Б\n- [ ] В\n## Всплыло за день\n- [ ] Г\n", null);
Check(string.Join(",", LinkedFile.Ordered(parsed, new[] { "В", "А" }, new Dictionary<string, string>()).Select(t => t.Title)) == "В,А,Б,Г", "file order: known first");
var shown = LinkedFile.Ordered(parsed, Array.Empty<string>(), new Dictionary<string, string>());
var moved = LinkedFile.OrderAfterMoving(shown[0], null, "Всплыло за день", shown);
Check(string.Join(",", moved) == "Б,В,Г,А", "file order: move to another group");
var regrouped = LinkedFile.Ordered(parsed, moved, new Dictionary<string, string> { ["А"] = "Всплыло за день" });
Check(regrouped[^1].Title == "А" && regrouped[^1].Section == "Всплыло за день" && regrouped[^1].RawLine == "- [ ] А", "file order: new group, same line");

// Motion loops stay smooth and seamless.
foreach (var (row, period) in new[] { (0, 4.8), (3, 9d), (5, 3.6), (7, 7.2), (8, 3.2) })
{
    var start = MotionTracks.At(row, 0); var end = MotionTracks.At(row, period);
    Check(Math.Abs(start.Tail - end.Tail) < 1e-8 && Math.Abs(start.Arm - end.Arm) < 1e-8 && Math.Abs(start.Lean - end.Lean) < 1e-8, "motion wraps " + row);
    var previous = start;
    for (int i = 1; i <= period * 30; i++)
    {
        var next = MotionTracks.At(row, i / 30d);
        Check(Math.Abs(next.Tail - previous.Tail) < 3 && Math.Abs(next.Arm - previous.Arm) < 3, "smooth motion " + row);
        previous = next;
    }
}
Console.WriteLine($"PASS: {checks} Windows checks (timer, tasks, done list, links, connected file, 0.5 migration, motion)");

if (args.Length == 1)
{
    // Inspect the compiled Windows assembly without executing platform code.
    using var file = File.OpenRead(args[0]);
    using var pe = new PEReader(file);
    var metadata = pe.GetMetadataReader();
    var entries = metadata.ManifestResources.Select(handle => metadata.GetManifestResource(handle)).ToArray();
    var resources = entries.Select(entry => metadata.GetString(entry.Name)).ToArray();
    Check(resources.Count(name => name.EndsWith(".png")) == 20, "all PNG layers embedded");
    Check(resources.Contains("Shiro.Assets.Shiro.ico"), "icon embedded");
    foreach (string font in new[] { "Onest-Variable.ttf", "Unbounded-Light.ttf", "Unbounded-Regular.ttf" }) Check(resources.Contains("Shiro.Assets." + font), "font " + font);
    foreach (string pack in new[] { "glass", "wood", "air" }) foreach (string e in new[] { "focus-end", "break-end", "task-done", "start" })
        Check(resources.Contains($"Shiro.Assets.{pack}-{e}.wav"), $"sound {pack}-{e}");
    Check(resources.Contains("Shiro.Assets.ambient-keyboard.wav"), "keyboard sound");
    var rigEntry = entries.Single(entry => metadata.GetString(entry.Name) == "Shiro.Assets.rig.json");
    var content = pe.GetSectionData(pe.PEHeaders.CorHeader!.ResourcesDirectory.RelativeVirtualAddress).GetContent();
    int offset = checked((int)rigEntry.Offset);
    int length = BitConverter.ToInt32(content.AsSpan(offset, 4));
    using var manifest = JsonDocument.Parse(System.Text.Encoding.UTF8.GetString(content.AsSpan(offset + 4, length)));
    foreach (var item in manifest.RootElement.EnumerateObject())
        foreach (string name in new[] { "body", "tail", "arm", "feet", "bug", "joints" })
            if (item.Value.TryGetProperty(name, out var filename))
                Check(resources.Contains("Shiro.Assets." + filename.GetString()), "embedded layer " + item.Name + "/" + name);
    Console.WriteLine("PASS: compiled Windows assembly includes rig layers, fonts, sounds and icon");
}
