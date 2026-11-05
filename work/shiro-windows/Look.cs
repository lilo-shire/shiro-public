using System.Drawing.Text;
using System.Runtime.InteropServices;

namespace Shiro;

// ---------- Language ----------
internal static class L
{
    internal static string Language = "ru";
    static readonly Dictionary<string, string> Ru = new()
    {
        ["focus"] = "Фокус", ["break"] = "Перерыв", ["start"] = "Начать", ["pause"] = "Пауза", ["resume"] = "Продолжить", ["reset"] = "Сбросить",
        ["tasks"] = "Задачи", ["addSection"] = "+ раздел", ["settings"] = "Настройки", ["hide"] = "Скрыть окно",
        ["theme"] = "Оформление", ["timer"] = "Таймер", ["scopeGlobal"] = "Общий для всех задач", ["scopeTask"] = "Свой у каждой задачи",
        ["helpGlobal"] = "Выбор задачи не меняет время.", ["helpTask"] = "У задачи сохраняется своё время, при выборе другой отсчёт встаёт на паузу.",
        ["workMin"] = "Фокус, мин", ["breakMin"] = "Перерыв, мин", ["volume"] = "Громкость", ["sound"] = "Звук",
        ["glass"] = "Стекло", ["wood"] = "Дерево", ["air"] = "Воздух", ["listen"] = "Послушать",
        ["notify"] = "Уведомлять в конце интервала", ["language"] = "Язык", ["windowSize"] = "Размер окна",
        ["ambient"] = "Звук клавиатуры во время фокуса", ["ambientVolume"] = "Громкость фона", ["menuAmbient"] = "Звук клавиатуры",
        ["rename"] = "Переименовать", ["delete"] = "Удалить", ["renameSection"] = "Переименовать раздел", ["deleteSection"] = "Удалить раздел",
        ["attachLink"] = "Прикрепить ссылку", ["editLink"] = "Изменить ссылку", ["removeLink"] = "Убрать ссылку", ["linkPlaceholder"] = "Ссылка, например figma.com/…",
        ["openLink"] = "Открыть ссылку", ["doneList"] = "Завершённые", ["clearDone"] = "Очистить", ["backToActive"] = "Вернуть в работу", ["deleteForever"] = "Удалить навсегда",
        ["cancel"] = "Отмена", ["add"] = "Добавить", ["createSection"] = "Создать раздел", ["save"] = "Сохранить",
        ["newTask"] = "Новая задача", ["sectionName"] = "Название раздела", ["taskName"] = "Название задачи", ["empty"] = "Пока пусто",
        ["markDone"] = "Отметить выполненной", ["reopen"] = "Вернуть задачу", ["taskActions"] = "Действия с задачей", ["sectionActions"] = "Действия с разделом",
        ["addTaskTo"] = "Добавить задачу в раздел", ["collapse"] = "Свернуть раздел", ["expand"] = "Развернуть раздел", ["pickTask"] = "Сначала выбери задачу",
        ["focusDone"] = "Фокус завершён", ["focusDoneBody"] = "Перерыв ждёт запуска", ["breakDone"] = "Перерыв завершён", ["breakDoneBody"] = "Фокус ждёт запуска",
        ["menuPanel"] = "Таймер и задачи", ["menuPlay"] = "Старт / пауза", ["menuShow"] = "Показать Широ", ["menuHide"] = "Скрыть Широ", ["menuQuit"] = "Выход",
        ["menuAddTask"] = "Добавить задачу…", ["defaultWork"] = "Работа", ["defaultPersonal"] = "Личное",
        ["addToFile"] = "Добавить в файл", ["importToShiro"] = "Добавить в Широ", ["inShiro"] = "Уже в Широ",
        ["fileMissing"] = "Файл не найден, Широ ждёт, пока он появится", ["fileEmpty"] = "В файле пока нет задач",
        ["fileTitle"] = "Файл задач", ["fileNone"] = "Не подключён", ["connectFile"] = "Подключить файл…", ["disconnectFile"] = "Отключить",
        ["fileIntro"] = "Выберите md-файл, например из Obsidian. Широ покажет его задачи отдельным блоком и будет дописывать туда новые. Задача — строка «- [ ] текст», раздел — «## Название».",
        ["alreadyRunning"] = "Широ уже запущен. Меню — у значка рядом с часами."
    };
    static readonly Dictionary<string, string> En = new()
    {
        ["focus"] = "Focus", ["break"] = "Break", ["start"] = "Start", ["pause"] = "Pause", ["resume"] = "Resume", ["reset"] = "Reset",
        ["tasks"] = "Tasks", ["addSection"] = "+ section", ["settings"] = "Settings", ["hide"] = "Hide window",
        ["theme"] = "Theme", ["timer"] = "Timer", ["scopeGlobal"] = "One timer for all tasks", ["scopeTask"] = "Separate timer per task",
        ["helpGlobal"] = "Picking a task doesn’t change the time.", ["helpTask"] = "Each task keeps its own time. Picking another task pauses the count.",
        ["workMin"] = "Focus, min", ["breakMin"] = "Break, min", ["volume"] = "Volume", ["sound"] = "Sound",
        ["glass"] = "Glass", ["wood"] = "Wood", ["air"] = "Air", ["listen"] = "Play",
        ["notify"] = "Notify when an interval ends", ["language"] = "Language", ["windowSize"] = "Window size",
        ["ambient"] = "Keyboard sound while focusing", ["ambientVolume"] = "Background volume", ["menuAmbient"] = "Keyboard sound",
        ["rename"] = "Rename", ["delete"] = "Delete", ["renameSection"] = "Rename section", ["deleteSection"] = "Delete section",
        ["attachLink"] = "Attach link", ["editLink"] = "Edit link", ["removeLink"] = "Remove link", ["linkPlaceholder"] = "Link, e.g. figma.com/…",
        ["openLink"] = "Open link", ["doneList"] = "Done", ["clearDone"] = "Clear", ["backToActive"] = "Back to active", ["deleteForever"] = "Delete forever",
        ["cancel"] = "Cancel", ["add"] = "Add", ["createSection"] = "Create section", ["save"] = "Save",
        ["newTask"] = "New task", ["sectionName"] = "Section name", ["taskName"] = "Task name", ["empty"] = "Nothing here yet",
        ["markDone"] = "Mark as done", ["reopen"] = "Reopen task", ["taskActions"] = "Task actions", ["sectionActions"] = "Section actions",
        ["addTaskTo"] = "Add a task to", ["collapse"] = "Collapse section", ["expand"] = "Expand section", ["pickTask"] = "Pick a task first",
        ["focusDone"] = "Focus done", ["focusDoneBody"] = "Your break is ready to start", ["breakDone"] = "Break over", ["breakDoneBody"] = "Focus is ready to start",
        ["menuPanel"] = "Timer and tasks", ["menuPlay"] = "Start / pause", ["menuShow"] = "Show Shiro", ["menuHide"] = "Hide Shiro", ["menuQuit"] = "Quit",
        ["menuAddTask"] = "Add task…", ["defaultWork"] = "Work", ["defaultPersonal"] = "Personal",
        ["addToFile"] = "Add to the file", ["importToShiro"] = "Add to Shiro", ["inShiro"] = "Already in Shiro",
        ["fileMissing"] = "File not found; Shiro waits for it to come back", ["fileEmpty"] = "No tasks in the file yet",
        ["fileTitle"] = "Task file", ["fileNone"] = "Not connected", ["connectFile"] = "Connect file…", ["disconnectFile"] = "Disconnect",
        ["fileIntro"] = "Pick a Markdown file, for example from Obsidian. Shiro shows its tasks as a separate block and adds new ones to it. A task is a line “- [ ] text”, a section is “## Name”.",
        ["alreadyRunning"] = "Shiro is already running. Its menu is at the icon next to the clock."
    };
    internal static string T(string key) => (Language == "en" ? En : Ru).GetValueOrDefault(key) ?? Ru.GetValueOrDefault(key) ?? key;
    internal static string Active(int n)
    {
        if (Language == "en") return $"{n} active";
        int a = n % 10, b = n % 100;
        return $"{n} " + (a == 1 && b != 11 ? "активная" : a >= 2 && a <= 4 && (b < 10 || b >= 20) ? "активные" : "активных");
    }
    internal static string DeleteSectionQuestion(string name, int n)
    {
        if (Language == "en") return $"Delete “{name}” and its {n} {(n == 1 ? "task" : "tasks")}?";
        bool one = n % 10 == 1 && n % 100 != 11;
        return $"Удалить «{name}» вместе с {n} {(one ? "задачей" : "задачами")}?";
    }
    internal static string ClearDoneQuestion(int n)
    {
        if (Language == "en") return $"Delete {n} done {(n == 1 ? "task" : "tasks")} forever?";
        int a = n % 10, b = n % 100;
        string words = a == 1 && b != 11 ? "завершённую задачу" : a >= 2 && a <= 4 && (b < 10 || b >= 20) ? "завершённые задачи" : "завершённых задач";
        return $"Удалить {n} {words} навсегда?";
    }
    internal static string MainLabel(TimerModel timer, double now) => T(timer.State.Running ? "pause" : timer.IsPartialAt(now) ? "resume" : "start");
}

// ---------- Colour schemes (same numbers and colours as on the Mac) ----------
internal sealed class Theme
{
    internal string Id = "", Number = "";
    internal Color Background, Ink, Muted, Popover, PopoverInk, HeadBackground, HeadInk, HeadMuted;
    internal Color[] BandFills = Array.Empty<Color>(), BandInks = Array.Empty<Color>();
    internal bool Dark;
    internal Color BandFill(int i) => BandFills[((i % BandFills.Length) + BandFills.Length) % BandFills.Length];
    internal Color BandInk(int i) => BandInks[((i % BandInks.Length) + BandInks.Length) % BandInks.Length];

    static Color H(string hex) => ColorTranslator.FromHtml(hex);
    static Theme Make(string id, string number, string bg, string ink, string muted, string pop, string popInk, bool dark, string[][] bands, string[]? head = null)
    {
        var t = new Theme { Id = id, Number = number, Background = H(bg), Ink = H(ink), Muted = H(muted), Popover = H(pop), PopoverInk = H(popInk), Dark = dark };
        t.HeadBackground = head != null ? H(head[0]) : t.Background;
        t.HeadInk = head != null ? H(head[1]) : t.Ink;
        t.HeadMuted = head != null ? H(head[2]) : t.Muted;
        t.BandFills = bands.Select(b => H(b[0])).ToArray();
        t.BandInks = bands.Select(b => b.Length > 1 ? H(b[1]) : t.Ink).ToArray();
        return t;
    }
    internal static readonly Theme[] All =
    {
        Make("pastel", "33", "#F5F3EF", "#1D1C21", "#8E8B93", "#FFFFFF", "#1D1C21", false, new[] { new[] { "#F3E3AA" }, new[] { "#F3CDBB" }, new[] { "#EEC8D7" }, new[] { "#D9D0F0" }, new[] { "#C6DAEF" }, new[] { "#CBE4D6" } }),
        Make("nature", "42", "#ECE6D8", "#25231A", "#8A8470", "#FAF7EF", "#25231A", false, new[] { new[] { "#DCCB96" }, new[] { "#CFA27A" }, new[] { "#B9C087" }, new[] { "#98A466" }, new[] { "#C8B188" } }),
        Make("ice", "71", "#EEF2F6", "#16202C", "#7C8897", "#FFFFFF", "#16202C", false, new[] { new[] { "#DEE6EF" }, new[] { "#CDD9E6" }, new[] { "#BCCBDD" }, new[] { "#AABDD3" } }),
        Make("juicy", "67", "#F4F1EC", "#121214", "#8A8790", "#FFFFFF", "#121214", false, new[] { new[] { "#FFC845" }, new[] { "#FF9469" }, new[] { "#F27DB9" }, new[] { "#A093F5" }, new[] { "#66A0F5" } }),
        Make("shiro", "00", "#0E0E10", "#F2F2F0", "#7C7C84", "#18181B", "#F2F2F0", true,
             new[] { new[] { "#F2F2F0", "#0E0E10" }, new[] { "#C5C8CE", "#0E0E10" }, new[] { "#1B1B1E", "#F2F2F0" }, new[] { "#2C2D32", "#F2F2F0" } }, new[] { "#C8102E", "#FFFFFF", "#FFB8C2" }),
        Make("mono", "10", "#F2F2F0", "#111112", "#8B8B8E", "#FFFFFF", "#111112", false, new[] { new[] { "#E6E6E3" }, new[] { "#DADAD6" }, new[] { "#CECEC9" }, new[] { "#C2C2BC" } }),
        Make("night", "90", "#131315", "#EDEDEF", "#7E7E86", "#232327", "#EDEDEF", true, new[] { new[] { "#1C1C1F" }, new[] { "#232326" }, new[] { "#2A2A2E" }, new[] { "#313136" } }),
        Make("bsod", "01", "#0A33B5", "#FFFFFF", "#9FB6FF", "#FFFFFF", "#0A33B5", true, new[] { new[] { "#0D3AC4" }, new[] { "#1244D1" }, new[] { "#184EDC" }, new[] { "#1F58E5" } })
    };
    internal static Theme Get(string? id) => All.FirstOrDefault(t => t.Id == id) ?? All[0];
}

internal static class Ink
{
    internal static Color A(Color c, double alpha) => Color.FromArgb(Math.Clamp((int)Math.Round(alpha * 255), 0, 255), c);
    internal static Color Blend(Color a, Color b, double t) => Color.FromArgb(255,
        (int)Math.Round(a.R + (b.R - a.R) * t), (int)Math.Round(a.G + (b.G - a.G) * t), (int)Math.Round(a.B + (b.B - a.B) * t));
}

// ---------- Fonts: Unbounded for numbers and the logo, Onest for text (embedded; GDI+ cannot pick a weight of a variable font) ----------
internal static class Fonts
{
    [DllImport("gdi32.dll")] static extern IntPtr AddFontMemResourceEx(IntPtr font, uint length, IntPtr reserved, ref uint fonts);
    static readonly PrivateFontCollection collection = new();
    static readonly Dictionary<string, Font> cache = new();
    static FontFamily? onest, unboundedLight, unbounded;
    static bool loaded;
    static void Load()
    {
        if (loaded) return;
        loaded = true;
        foreach (string name in new[] { "Onest-Variable.ttf", "Unbounded-Light.ttf", "Unbounded-Regular.ttf" })
        {
            try
            {
                using var stream = Assets.Open(name);
                using var memory = new MemoryStream(); stream.CopyTo(memory);
                byte[] data = memory.ToArray();
                IntPtr pointer = Marshal.AllocCoTaskMem(data.Length);   // kept for the life of the app, as GDI+ requires
                Marshal.Copy(data, 0, pointer, data.Length);
                collection.AddMemoryFont(pointer, data.Length);
                uint count = 0; AddFontMemResourceEx(pointer, (uint)data.Length, IntPtr.Zero, ref count);   // lets text boxes (GDI) use it too
            }
            catch (Exception error) when (error is IOException or ArgumentException or ExternalException) { }
        }
        foreach (var family in collection.Families)
        {
            if (family.Name == "Onest") onest = family;
            else if (family.Name.StartsWith("Unbounded") && family.Name.Contains("Light")) unboundedLight = family;
            else if (family.Name == "Unbounded") unbounded = family;
        }
    }
    static Font Make(FontFamily? family, string fallback, float size, FontStyle style)
    {
        string key = $"{family?.Name ?? fallback}-{size:0.0}-{style}";
        if (cache.TryGetValue(key, out var font)) return font;
        if (family != null && !family.IsStyleAvailable(style)) style = FontStyle.Regular;
        font = family != null ? new Font(family, size, style, GraphicsUnit.Pixel) : new Font(fallback, size, style, GraphicsUnit.Pixel);
        cache[key] = font; return font;
    }
    internal static Font Display(float size, int weight) { Load(); return Make(weight <= 300 ? unboundedLight ?? unbounded : unbounded, "Segoe UI Light", size, FontStyle.Regular); }
    internal static Font Text(float size) { Load(); return Make(onest, "Segoe UI", size, FontStyle.Regular); }
    internal static bool HasBold => onest == null || onest.IsStyleAvailable(FontStyle.Bold);
}
