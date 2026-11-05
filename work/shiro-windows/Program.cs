using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Shiro;

internal static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            if (args.Contains("--check-animation")) { CheckAnimation(); return; }
            using var mutex = new Mutex(true, @"Local\ShiroPomodoro", out bool first);
            L.Language = AppState.SystemLanguage();
            if (!first) { MessageBox.Show(L.T("alreadyRunning"), "Широ"); return; }
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.ThrowException);
            using var context = new ShiroContext();
            Application.Run(context);
        }
        catch (Exception error)
        {
            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Shiro", "error.txt");
            try { Directory.CreateDirectory(Path.GetDirectoryName(path)!); File.WriteAllText(path, error.ToString()); } catch { }
            MessageBox.Show("Не удалось запустить Широ. Подробности ошибки:\n" + path + "\n\n" + error.Message, "Широ", MessageBoxButtons.OK, MessageBoxIcon.Error);
            Environment.ExitCode = 1;
        }
    }
    static void CheckAnimation()
    {
        using var rig = new AnimationRig();
        using var image = new Bitmap(192, 208, PixelFormat.Format32bppPArgb);
        foreach (int row in new[] { 0, 3, 5, 7, 8 }) for (int frame = 0; frame < 108; frame++)
        {
            using var g = Graphics.FromImage(image); g.Clear(Color.Transparent);
            rig.Draw(g, row, frame / 30d, new(0, 0, 192, 208));
            for (int x = 0; x < 192; x++) if (image.GetPixel(x, 0).A != 0 || image.GetPixel(x, 207).A != 0) throw new InvalidOperationException("Vertical clipping: " + row);
            for (int y = 0; y < 208; y++) if (image.GetPixel(0, y).A != 0 || image.GetPixel(191, y).A != 0) throw new InvalidOperationException("Horizontal clipping: " + row);
        }
        File.WriteAllText(Path.Combine(AppContext.BaseDirectory, "animation-check.txt"), "PASS: 540 frames; no edge clipping; cached native layers.");
    }
}

internal sealed class ShiroContext : ApplicationContext, IPanelHost, ISettingsHost
{
    [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr icon);
    internal static double Now => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000d;
    readonly string statePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Shiro", "state.json");
    readonly AppState state;
    readonly PetWindow pet;
    readonly PanelForm panel;
    SettingsForm? settings;
    readonly NotifyIcon tray;
    readonly Icon appIcon;
    Icon? trayIcon;
    IntPtr trayHandle;
    readonly ContextMenuStrip menu = new();
    readonly Audio audio = new();
    readonly System.Windows.Forms.Timer clock = new() { Interval = 500 };
    readonly System.Windows.Forms.Timer animation = new() { Interval = 67 };
    readonly Stopwatch motion = Stopwatch.StartNew(), uptime = Stopwatch.StartNew();
    int row, reactionRow;
    double reactionUntil, lastFileCheck, ambientPreviewUntil, marqueeStartedAt = -1;
    string? lastBadge, marqueeTitle, fileSignature;
    List<FileTask> fileTasks = new();
    bool fileMissing, disposed, saveWarningShown;

    public TimerModel Timer { get; }
    public TaskStore Store { get; }
    public Theme Theme => global::Shiro.Theme.Get(state.Theme);
    public string Scope => state.Scope;
    public double UiScale => state.UiScale;
    public string? FileName => state.LinkedFile == null ? null : Path.GetFileNameWithoutExtension(state.LinkedFile);
    public IReadOnlyList<FileTask> FileTasks => fileTasks;
    public bool FileMissing => fileMissing;
    public bool FileCollapsed => state.LinkedFileCollapsed;
    public int FileIndex => state.LinkedFileIndex;
    public string? ActiveFileTitle => state.ActiveFileTask;
    public string ThemeId => Theme.Id;
    public string Language => L.Language;
    public string SoundPack => state.SoundPack;
    public double Volume => state.Volume;
    public bool Notify => state.Notify;
    public bool Ambient => state.Ambient;
    public double AmbientVolume => state.AmbientVolume;
    public double WorkMinutes => Timer.State.WorkSeconds / 60;
    public double BreakMinutes => Timer.State.BreakSeconds / 60;
    public string? LinkedFileName => state.LinkedFile == null ? null : Path.GetFileName(state.LinkedFile);
    internal int CurrentRow => row;
    internal double MotionSeconds => motion.Elapsed.TotalSeconds;
    internal double Seconds => uptime.Elapsed.TotalSeconds;

    internal ShiroContext()
    {
        string? json = null;
        try { if (File.Exists(statePath)) json = File.ReadAllText(statePath); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        state = AppState.Load(json);
        L.Language = state.Language == "en" || state.Language == "ru" ? state.Language : AppState.SystemLanguage();
        state.Language = L.Language;
        if (!new[] { "glass", "wood", "air" }.Contains(state.SoundPack)) state.SoundPack = "glass";
        state.UiScale = Math.Clamp(double.IsFinite(state.UiScale) ? state.UiScale : .72, .5, 1.5);
        state.FileTaskRemaining ??= new(); state.FileTaskOrder ??= new(); state.FileTaskGroups ??= new();
        Timer = new(state.Timer);
        state.Timer = Timer.State;
        Store = new TaskStore(state.Checklist, new[] { L.T("defaultWork"), L.T("defaultPersonal") });
        state.Checklist = Store.State;
        if (Timer.State.Running && Timer.State.Phase == "work" && CreditsTasks && Store.FocusAnchorRemaining < 0) Store.BeginFocus(Timer.RemainingAt(Now));
        ReloadFile();

        appIcon = Assets.Icon();
        pet = new(this) { Icon = appIcon };
        panel = new(this) { Icon = appIcon };
        tray = new() { Icon = MakeTrayIcon(), Text = "Широ", Visible = true, ContextMenuStrip = menu };
        tray.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) TogglePanel(); };
        tray.BalloonTipClicked += (_, _) => { if (!panel.Visible) TogglePanel(); };
        menu.Opening += (_, _) => RebuildMenu();
        pet.FormClosed += (_, _) => ExitThread();
        clock.Tick += (_, _) => Tick();
        animation.Tick += (_, _) => { if (row != DesiredRow()) ChooseAnimation(); pet.Render(row, motion.Elapsed.TotalSeconds); };
        pet.Show(); pet.RestoreLocation(state.X, state.Y);
        Tick(); ChooseAnimation(); clock.Start(); animation.Start();
        Application.ApplicationExit += (_, _) => Save();
        Microsoft.Win32.SystemEvents.DisplaySettingsChanged += DisplayChanged;
    }
    void DisplayChanged(object? sender, EventArgs e)
    {
        if (disposed || pet.IsDisposed) return;
        try { pet.BeginInvoke(() => { if (!pet.IsDisposed) { pet.ClampLocation(); Save(); } }); } catch (InvalidOperationException) { }
    }

    // ---------- Menu-bar heart (white on a dark taskbar, black on a light one) ----------
    Icon MakeTrayIcon()
    {
        bool light = false;
        try { light = (Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "SystemUsesLightTheme", 0) as int?) == 1; } catch { }
        using var bitmap = new Bitmap(32, 32, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(Color.Transparent);
            using var path = new GraphicsPath();
            PointF P(float x, float y) => new(x * 32 / 18f, (16 - y) * 32 / 18f + 1);
            path.AddBezier(P(9, 2.2f), P(6.4f, 4.3f), P(2.2f, 6.6f), P(2.2f, 9.6f));
            path.AddBezier(P(2.2f, 9.6f), P(2.2f, 12), P(3.8f, 13.6f), P(5.6f, 13.6f));
            path.AddBezier(P(5.6f, 13.6f), P(7.2f, 13.6f), P(8.4f, 12.6f), P(9, 11.4f));
            path.AddBezier(P(9, 11.4f), P(9.6f, 12.6f), P(10.8f, 13.6f), P(12.4f, 13.6f));
            path.AddBezier(P(12.4f, 13.6f), P(14.2f, 13.6f), P(15.8f, 12), P(15.8f, 9.6f));
            path.AddBezier(P(15.8f, 9.6f), P(15.8f, 6.6f), P(11.6f, 4.3f), P(9, 2.2f));
            path.CloseFigure();
            using var pen = new Pen(light ? Color.Black : Color.White, 2.6f) { LineJoin = LineJoin.Round };
            g.DrawPath(pen, path);
        }
        // The handle stays alive while the icon is shown and is destroyed on exit.
        trayHandle = bitmap.GetHicon();
        trayIcon = Icon.FromHandle(trayHandle);
        return trayIcon;
    }

    // ---------- Timer coordination (same rules as the Mac) ----------
    // Focus time counts towards a task only with a separate timer per task; a shared timer is not tied to one task.
    bool CreditsTasks => state.Scope == "task" && Store.ActiveTaskId != null;
    bool HasSelection => state.ActiveFileTask != null || Store.ActiveTaskId != null;
    void CreditCurrentFocus() { if (Timer.State.Running && Timer.State.Phase == "work" && CreditsTasks) Store.Credit(Timer.RemainingAt(Now), false); }
    void StashSelectedTaskTime()
    {
        if (state.Scope != "task") return;
        double value = Timer.WorkRemainingAt(Now);
        if (state.ActiveFileTask != null) state.FileTaskRemaining[state.ActiveFileTask] = value;
        else if (Store.ActiveTaskId != null) Store.SetRemaining(Store.ActiveTaskId, value);
    }
    void LoadSelectedTaskTime()
    {
        if (state.Scope != "task") return;
        double value = state.ActiveFileTask != null ? state.FileTaskRemaining.GetValueOrDefault(state.ActiveFileTask, -1) : Store.RemainingOf(Store.ActiveTaskId);
        Timer.LoadWorkRemaining(value, Now);
    }
    void StopFocusIfRunning() { if (Timer.State.Running && Timer.State.Phase == "work") { CreditCurrentFocus(); Timer.Pause(Now); } }
    // Only one current task at a time: choosing a file task clears the Shiro selection and the other way round.
    void KeepFileSelection() { if (state.ActiveFileTask != null) { Store.ActiveTaskId = null; Store.FocusAnchorRemaining = -1; } }
    void SetReaction(int next, double duration) { reactionRow = next; reactionUntil = Now + duration; }
    internal string? ActiveTaskTitle => state.ActiveFileTask ?? Store.Task(Store.ActiveTaskId)?.Title;

    void Tick()
    {
        // The daily file is replaced every morning: check its path every two seconds and re-read on any change.
        if (state.LinkedFile != null && Now - lastFileCheck >= 2)
        {
            lastFileCheck = Now;
            if (FileSignature() != fileSignature) { ReloadFile(); panel.Reload(); }
        }
        string before = Timer.State.Phase; bool credits = CreditsTasks;
        string? transition = Timer.Tick(Now);
        if (transition == "workFinished" && before == "work" && state.ActiveFileTask != null && state.Scope == "task") state.FileTaskRemaining.Remove(state.ActiveFileTask);
        if (transition == "workFinished" && before == "work" && credits) { Store.Credit(0, true); Store.SetRemaining(Store.ActiveTaskId, -1); }
        if (transition != null) IntervalFinished(transition);
        if (transition != null) panel.Reload(); else panel.RefreshTimer();
        if (state.Scope == "task" && panel.Visible) panel.Invalidate();
        string title = ActiveTaskTitle ?? "";
        if (title != (marqueeTitle ?? "")) { bool first = marqueeTitle == null; marqueeTitle = title; if (!first) PlayMarquee(); }
        string badge = BadgeTime + Timer.State.Phase + Timer.State.Running + title + MarqueeRunning;
        if (badge != lastBadge) { lastBadge = badge; tray.Text = ("Широ " + BadgeTime).Length > 63 ? "Широ" : "Широ " + BadgeTime; }
        ChooseAnimation();
        UpdateAmbient();
    }
    internal string BadgeTime { get { int s = (int)Math.Ceiling(Math.Max(0, Timer.RemainingAt(Now)) - .0001); return $"{s / 60:00}:{s % 60:00}"; } }
    void IntervalFinished(string transition)
    {
        bool focus = transition == "workFinished";
        if (focus) SetReaction(8, 3.2); else SetReaction(3, 2.2);
        audio.Play(state.SoundPack + (focus ? "-focus-end" : "-break-end"), state.Volume);
        if (state.Notify) tray.ShowBalloonTip(6000, L.T(focus ? "focusDone" : "breakDone"), L.T(focus ? "focusDoneBody" : "breakDoneBody"), ToolTipIcon.None);
        PlayMarquee();
        Save();
    }
    int DesiredRow() => Now < reactionUntil ? reactionRow : !Timer.State.Running ? 0 : Timer.State.Phase == "break" ? 0 : 7;
    void ChooseAnimation()
    {
        int desired = DesiredRow();
        int interval = desired == 0 && !MarqueeRunning ? 67 : 33;
        // Only a new row restarts the motion; a frame-rate change for the ticker keeps it running smoothly.
        if (desired != row) { row = desired; motion.Restart(); }
        if (animation.Interval != interval) animation.Interval = interval;
    }

    // ---------- Ticker on the badge: runs once after an action, otherwise the start of the title stays ----------
    internal const double MarqueeGap = 36, MarqueeSpeed = 34, MarqueePause = .6;
    internal void PlayMarquee() { marqueeStartedAt = Seconds; ChooseAnimation(); }
    internal bool MarqueeRunning
    {
        get
        {
            string? title = ActiveTaskTitle;
            if (string.IsNullOrEmpty(title) || marqueeStartedAt < 0 || SystemInformation.UIEffectsEnabled == false) return false;
            double width = Draw.Measure(title, Fonts.Text(12)).Width;
            if (width <= 172 - 28) return false;
            return Seconds - marqueeStartedAt < MarqueePause + (width + MarqueeGap) / MarqueeSpeed;
        }
    }
    internal double MarqueeShift(double width) { double t = Seconds - marqueeStartedAt; return t < MarqueePause ? 0 : Math.Min((t - MarqueePause) * MarqueeSpeed, width + MarqueeGap); }

    // ---------- Background keyboard sound ----------
    void UpdateAmbient()
    {
        bool wanted = state.Ambient && state.AmbientVolume > 0 && ((Timer.State.Running && Timer.State.Phase == "work") || Now < ambientPreviewUntil);
        audio.Ambient(wanted, state.AmbientVolume);
    }

    // ---------- Panel ----------
    internal void TogglePanel()
    {
        PlayMarquee();
        if (panel.Visible) { settings?.Hide(); panel.Hide(); return; }
        ContentChanged(); PlacePanel();
        panel.Show(); panel.Activate(); pet.BringToFront();
    }
    void PlacePanel()
    {
        // The window opens left of Shiro and a little higher than his feet, so he stands at its right edge.
        var area = Screen.FromControl(pet).WorkingArea;
        float f = pet.DeviceDpi / 96f;
        int left = pet.Left + (int)(30 * f) - panel.Width, right = pet.Left + (int)(162 * f);
        int x = left >= area.Left ? left : right + panel.Width <= area.Right ? right : area.Left;
        int y = pet.Top + (int)(212 * f) - (int)(64 * f) - panel.Height;
        panel.Location = new(Math.Clamp(x, area.Left, Math.Max(area.Left, area.Right - panel.Width)), Math.Clamp(y, area.Top, Math.Max(area.Top, area.Bottom - panel.Height)));
    }
    public void ContentChanged()
    {
        if (panel == null) return;
        var area = Screen.FromControl(pet).WorkingArea;
        int width = panel.PreferredWidth, height = Math.Min(panel.PreferredHeight, area.Height - 40);
        if (panel.ClientSize.Width == width && panel.ClientSize.Height == height) return;
        // A size change keeps the edge next to Shiro and the bottom in place.
        int right = panel.Right, bottom = panel.Bottom;
        panel.ClientSize = new(width, height);
        if (panel.Visible) panel.Location = new(right - panel.Width, Math.Max(area.Top, bottom - panel.Height));
        panel.Invalidate();
    }
    void AfterTaskChange() { Save(); panel.Reload(); Tick(); }

    public void ToggleTimer()
    {
        if (Timer.State.Running) { CreditCurrentFocus(); Timer.Pause(Now); reactionUntil = 0; }
        else
        {
            bool focus = Timer.State.Phase == "work";
            if (focus && state.Scope == "task" && !HasSelection) { panel.ShowToast(L.T("pickTask")); return; }
            Timer.Start(Now);
            if (focus && CreditsTasks) Store.BeginFocus(Timer.RemainingAt(Now));
            // A break opens with the one-off cockroach scare, then calm rest.
            if (focus) reactionUntil = 0; else SetReaction(5, 3.6);
            audio.Play(state.SoundPack + "-start", state.Volume * .45);
        }
        PlayMarquee(); Save(); Tick();
    }
    public void ResetTimer()
    {
        CreditCurrentFocus(); Timer.Reset(); Store.FocusAnchorRemaining = -1;
        if (Timer.State.Phase == "work") StashSelectedTaskTime();
        reactionUntil = 0; PlayMarquee(); Save(); Tick();
    }
    public void SwitchPhase(string phase)
    {
        if (phase == Timer.State.Phase) return;
        CreditCurrentFocus(); Timer.SwitchTo(phase, Now); Store.FocusAnchorRemaining = -1; reactionUntil = 0;
        PlayMarquee(); Save(); Tick();
    }
    public void SelectTask(string id)
    {
        if (Store.ActiveTaskId == id && state.ActiveFileTask == null) return;
        bool separate = state.Scope == "task";
        if (separate) { CreditCurrentFocus(); StashSelectedTaskTime(); }
        state.ActiveFileTask = null;
        if (Store.ActiveTaskId == id) Store.ActiveTaskId = null;
        if (!Store.Select(id)) return;
        if (separate) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void ToggleTask(string id)
    {
        if (Store.ActiveTaskId == id) { StopFocusIfRunning(); StashSelectedTaskTime(); }
        string? before = Store.ActiveTaskId;
        bool done = Store.Toggle(id);
        if (done) { SetReaction(3, 1.8); audio.Play(state.SoundPack + "-task-done", state.Volume * .8); }
        KeepFileSelection();
        if (before != Store.ActiveTaskId) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void AddTask(string title, string sectionId)
    {
        string? before = Store.ActiveTaskId;
        if (Store.Add(title, sectionId) == null) return;
        KeepFileSelection();
        if (before == null && Store.ActiveTaskId != null) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public string? AddSection(string title) { string? id = Store.AddSection(title); AfterTaskChange(); return id; }
    public void RenameTask(string id, string title) { Store.Rename(id, title); AfterTaskChange(); }
    public void RenameSection(string id, string title) { Store.RenameSection(id, title); AfterTaskChange(); }
    public void DeleteTask(string id)
    {
        if (Store.ActiveTaskId == id) StopFocusIfRunning();
        string? before = Store.ActiveTaskId;
        Store.Delete(id);
        if (before != Store.ActiveTaskId) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void DeleteSection(string id)
    {
        string? before = Store.ActiveTaskId;
        if (Store.Task(before)?.SectionId == id) StopFocusIfRunning();
        Store.DeleteSection(id);
        if (before != Store.ActiveTaskId) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void MoveTask(string id, string sectionId, string? beforeId)
    {
        string? before = Store.ActiveTaskId;
        if (!Store.Move(id, sectionId, beforeId)) return;
        Store.ExpandSection(sectionId); KeepFileSelection();
        if (before != Store.ActiveTaskId) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void SetLink(string id, string link) { Store.SetLink(id, link); AfterTaskChange(); }
    public void ToggleDoneList() { Store.ToggleDoneCollapsed(); AfterTaskChange(); }
    public void ClearDone() { Store.ClearDone(); AfterTaskChange(); }
    public void ToggleSection(string id) { Store.ToggleSection(id); AfterTaskChange(); }
    public void ExpandSection(string id) { Store.ExpandSection(id); AfterTaskChange(); }
    public void ReorderBlocks(List<string> keys)
    {
        int index = 0;
        foreach (string key in keys) { if (key == "file") { state.LinkedFileIndex = index; continue; } Store.MoveSection(key, index++); }
        AfterTaskChange();
    }
    public void ShowSettings()
    {
        if (settings?.Visible == true) { settings.Hide(); return; }
        if (settings != null && (DateTime.UtcNow - settings.HiddenAt).TotalMilliseconds < 400) return;
        settings ??= new SettingsForm(this);
        settings.Fill();
        var area = Screen.FromControl(panel).WorkingArea;
        int x = panel.Left - settings.Width - 8 >= area.Left ? panel.Left - settings.Width - 8 : Math.Min(panel.Right + 8, area.Right - settings.Width);
        settings.Location = new(x, Math.Clamp(panel.Top, area.Top, Math.Max(area.Top, area.Bottom - settings.Height)));
        settings.Show(); settings.Activate();
    }
    public void ClosePanel() { settings?.Hide(); panel.Hide(); PlayMarquee(); }

    // ---------- Connected file ----------
    string FileSignature()
    {
        try { var info = new FileInfo(state.LinkedFile!); return info.Exists ? info.Length + "-" + info.LastWriteTimeUtc.Ticks + "-" + info.CreationTimeUtc.Ticks : "missing"; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException) { return "missing"; }
    }
    string? ReadFile() { try { return File.ReadAllText(state.LinkedFile!); } catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException) { return null; } }
    void ReloadFile()
    {
        if (state.LinkedFile == null) { fileTasks = new(); fileMissing = false; fileSignature = null; return; }
        fileSignature = FileSignature();
        string? text = ReadFile();
        fileMissing = text == null;
        var parsed = text != null ? LinkedFile.Parse(text, state.LinkedFile) : new List<FileTask>();
        if (text != null)
        {
            // Forget the order of tasks that are no longer in the file (the daily note is replaced every morning).
            var present = parsed.Select(t => t.Title).ToHashSet();
            state.FileTaskOrder = state.FileTaskOrder.Where(present.Contains).ToList();
            foreach (string key in state.FileTaskGroups.Keys.ToList()) if (!present.Contains(key)) state.FileTaskGroups.Remove(key);
        }
        fileTasks = LinkedFile.Ordered(parsed, state.FileTaskOrder, state.FileTaskGroups);
        DropFileSelectionIfGone();
    }
    void DropFileSelectionIfGone()
    {
        if (state.ActiveFileTask == null || fileMissing) return;
        if (fileTasks.Any(t => !t.Done && t.Title == state.ActiveFileTask)) return;
        // The task was ticked, renamed or the day was replaced: fall back to the first open Shiro task.
        StopFocusIfRunning();
        state.ActiveFileTask = null;
        Store.ActiveTaskId = Store.FirstOpen()?.Id;
        LoadSelectedTaskTime();
    }
    void WriteFile(string text)
    {
        try { string temporary = state.LinkedFile + ".shiro-tmp"; File.WriteAllText(temporary, text); File.Move(temporary, state.LinkedFile!, true); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { panel.ShowToast(e.Message); }
    }
    // The only writes Shiro makes to the file: one "- [ ] text" line, or "[ ]" ↔ "[x]" of one task. The file is read again right before writing.
    public void AddTaskToFile(string title)
    {
        if (state.LinkedFile == null) return;
        string? text = ReadFile();
        if (text == null) { panel.ShowToast(L.T("fileMissing")); ReloadFile(); panel.Reload(); return; }
        WriteFile(LinkedFile.Append(text, title));
        ReloadFile(); panel.Reload();
    }
    public void ToggleFileTask(int index)
    {
        if (state.LinkedFile == null || index < 0 || index >= fileTasks.Count) return;
        var task = fileTasks[index];
        string? text = ReadFile(), next = text != null ? LinkedFile.SetDone(text, task, !task.Done) : null;
        if (next != null) { WriteFile(next); if (!task.Done) { SetReaction(3, 1.8); audio.Play(state.SoundPack + "-task-done", state.Volume * .8); } }
        ReloadFile(); panel.Reload(); Tick();
    }
    public void SelectFileTask(int index)
    {
        if (index < 0 || index >= fileTasks.Count) return;
        var task = fileTasks[index];
        if (task.Done || task.Title == state.ActiveFileTask) return;
        bool separate = state.Scope == "task";
        if (separate) { CreditCurrentFocus(); StashSelectedTaskTime(); if (Timer.State.Running && Timer.State.Phase == "work") Timer.Pause(Now); }
        state.ActiveFileTask = task.Title; KeepFileSelection();
        if (separate) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void MoveFileTask(int index, int beforeIndex, string section)
    {
        if (index < 0 || index >= fileTasks.Count) return;
        var moved = fileTasks[index]; var before = beforeIndex >= 0 && beforeIndex < fileTasks.Count ? fileTasks[beforeIndex] : null;
        string group = before?.Section ?? section;
        state.FileTaskOrder = LinkedFile.OrderAfterMoving(moved, before, group, fileTasks);
        // Remember the group only when the task left the one it has in the file.
        string? text = ReadFile();
        string? home = text != null ? LinkedFile.Parse(text, state.LinkedFile).FirstOrDefault(t => t.Title == moved.Title)?.Section : null;
        if (home != null && home != group) state.FileTaskGroups[moved.Title] = group; else state.FileTaskGroups.Remove(moved.Title);
        ReloadFile(); Save(); panel.Reload();
    }
    public void ImportFileTask(int index, string sectionId, string? beforeId)
    {
        if (index < 0 || index >= fileTasks.Count) return;
        var source = fileTasks[index]; string? before = Store.ActiveTaskId;
        string? created = Store.Add(source.Title, sectionId);
        if (created == null) return;
        if (!string.IsNullOrEmpty(source.Link)) Store.SetLink(created, source.Link);
        if (beforeId != null) Store.Move(created, sectionId, beforeId);
        Store.ExpandSection(sectionId); KeepFileSelection();
        if (before == null && Store.ActiveTaskId != null) LoadSelectedTaskTime();
        AfterTaskChange();
    }
    public void ImportFileTaskMenu(int index, Point screen)
    {
        if (Store.Sections.Count == 0) Store.AddSection(L.T("defaultWork"));
        if (Store.Sections.Count == 1) { ImportFileTask(index, Store.Sections[0].Id, null); return; }
        var choose = new ContextMenuStrip();
        foreach (var section in Store.Sections) { string id = section.Id; choose.Items.Add(section.Title, null, (_, _) => ImportFileTask(index, id, null)); }
        choose.Closed += (_, _) => panel.BeginInvoke(() => choose.Dispose());
        choose.Show(screen);
    }
    public void ToggleFileBlock() { state.LinkedFileCollapsed = !state.LinkedFileCollapsed; Save(); panel.Reload(); }
    public void ConnectFile()
    {
        if (MessageBox.Show(L.T("fileIntro"), L.T("fileTitle"), MessageBoxButtons.OKCancel, MessageBoxIcon.Information) != DialogResult.OK) return;
        using var dialog = new OpenFileDialog { Filter = "Markdown (*.md)|*.md|*.*|*.*", Title = L.T("connectFile"), InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments) };
        if (dialog.ShowDialog() != DialogResult.OK) return;
        state.LinkedFile = dialog.FileName; state.LinkedFileCollapsed = false;
        ReloadFile(); Save(); panel.Reload();
        if (!panel.Visible) TogglePanel();
    }
    public void DisconnectFile()
    {
        if (state.ActiveFileTask != null) { StopFocusIfRunning(); state.ActiveFileTask = null; Store.ActiveTaskId = Store.FirstOpen()?.Id; LoadSelectedTaskTime(); }
        state.LinkedFile = null; ReloadFile(); Save(); panel.Reload();
    }

    // ---------- Settings ----------
    public void ChangeTheme(string id) { state.Theme = global::Shiro.Theme.Get(id).Id; Save(); panel.Reload(); pet.Render(row, MotionSeconds); }
    public void ChangeLanguage(string language) { L.Language = language == "en" ? "en" : "ru"; state.Language = L.Language; Save(); panel.Reload(); }
    public void ChangeScope(string scope)
    {
        scope = scope == "task" ? "task" : "global";
        if (scope == state.Scope) return;
        CreditCurrentFocus();
        if (Timer.State.Running && Timer.State.Phase == "work") Timer.Pause(Now);
        if (scope == "task") { state.GlobalWorkRemaining = Timer.WorkRemainingAt(Now); state.Scope = scope; LoadSelectedTaskTime(); }
        else { StashSelectedTaskTime(); state.Scope = scope; Timer.LoadWorkRemaining(state.GlobalWorkRemaining, Now); }
        Store.FocusAnchorRemaining = -1; Save(); panel.Reload(); Tick();
    }
    public void ChangeMinutes(double work, double rest)
    {
        double oldWork = Timer.State.WorkSeconds;
        Timer.SetMinutes(work, rest);
        if (Timer.State.WorkSeconds != oldWork)
        {
            foreach (var task in Store.Tasks) if (task.Remaining > Timer.State.WorkSeconds) task.Remaining = Timer.State.WorkSeconds;
            if (state.GlobalWorkRemaining > Timer.State.WorkSeconds) state.GlobalWorkRemaining = -1;
        }
        if (!Timer.State.Running) Store.FocusAnchorRemaining = -1;
        Save(); panel.Reload(); Tick();
    }
    public void ChangeVolume(double volume) { state.Volume = Math.Clamp(volume, 0, 1); Save(); }
    public void ChangeScale(double scale) { state.UiScale = Math.Clamp(scale, .5, 1.5); ContentChanged(); if (panel.Visible) PlacePanel(); Save(); }
    public void ChangeSoundPack(string pack) { state.SoundPack = pack; Save(); }
    public void ChangeNotify(bool on) { state.Notify = on; Save(); }
    public void PreviewSound() => audio.Play(state.SoundPack + "-focus-end", state.Volume);
    public void ChangeAmbient(bool on)
    {
        state.Ambient = on;
        // Switching it on outside focus plays three seconds so you hear what it is.
        if (on && !(Timer.State.Running && Timer.State.Phase == "work")) ambientPreviewUntil = Now + 3;
        Save(); UpdateAmbient();
    }
    public void ChangeAmbientVolume(double volume)
    {
        state.AmbientVolume = Math.Clamp(volume, 0, 1);
        if (!(Timer.State.Running && Timer.State.Phase == "work")) ambientPreviewUntil = Now + 2;
        Save(); UpdateAmbient();
    }

    // ---------- Tray menu ----------
    void RebuildMenu()
    {
        menu.Items.Clear();
        menu.Items.Add(L.T("menuPanel"), null, (_, _) => TogglePanel());
        menu.Items.Add(L.T("menuPlay"), null, (_, _) => ToggleTimer());
        var ambient = new ToolStripMenuItem(L.T("menuAmbient")) { Checked = state.Ambient };
        ambient.Click += (_, _) => { ChangeAmbient(!state.Ambient); settings?.Fill(); };
        menu.Items.Add(ambient);
        menu.Items.Add(new ToolStripSeparator());
        var tasks = new ToolStripMenuItem(L.T("tasks"));
        tasks.DropDownItems.Add(L.T("menuAddTask"), null, (_, _) =>
        {
            if (!panel.Visible) TogglePanel();
            string? section = Store.Sections.FirstOrDefault()?.Id ?? Store.AddSection(L.T("defaultWork"));
            if (section != null) panel.BeginAddingTask(section);
        });
        int shown = 0;
        foreach (var section in Store.Sections) foreach (var task in Store.OpenIn(section.Id))
        {
            if (shown++ >= 8) break;
            string id = task.Id;
            tasks.DropDownItems.Add(new ToolStripMenuItem(task.Title, null, (_, _) => SelectTask(id)) { Checked = Store.ActiveTaskId == id && state.ActiveFileTask == null });
        }
        menu.Items.Add(tasks);
        menu.Items.Add(L.T("menuShow"), null, (_, _) => { pet.Show(); pet.BringToFront(); });
        menu.Items.Add(L.T("menuHide"), null, (_, _) => { pet.Hide(); ClosePanel(); });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(L.T("menuQuit"), null, (_, _) => ExitThread());
    }
    internal void ShowContextMenu(Point location) { RebuildMenu(); menu.Show(location); }
    internal Theme CurrentTheme => Theme;

    internal void Save()
    {
        if (disposed) return;
        StashSelectedTaskTime();
        if (pet.Visible || pet.IsHandleCreated) { state.X = pet.Left; state.Y = pet.Top; }
        state.Timer = Timer.State; state.Checklist = Store.State;
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(statePath)!);
            string temporary = statePath + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(state));
            File.Move(temporary, statePath, true);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            if (!saveWarningShown) { saveWarningShown = true; MessageBox.Show("Не удалось сохранить настройки.\n\n" + error.Message, "Широ"); }
        }
    }
    protected override void ExitThreadCore() { Save(); base.ExitThreadCore(); }
    protected override void Dispose(bool disposing)
    {
        if (disposing && !disposed)
        {
            Save(); disposed = true;
            Microsoft.Win32.SystemEvents.DisplaySettingsChanged -= DisplayChanged;
            clock.Stop(); animation.Stop(); clock.Dispose(); animation.Dispose(); audio.Dispose();
            tray.Visible = false; tray.Dispose(); trayIcon?.Dispose(); if (trayHandle != IntPtr.Zero) DestroyIcon(trayHandle); menu.Dispose(); settings?.Dispose(); panel.Dispose(); pet.Dispose(); appIcon.Dispose();
        }
        base.Dispose(disposing);
    }
}

internal sealed class PetWindow : LayeredWindow
{
    readonly ShiroContext owner;
    readonly AnimationRig rig = new();
    Point dragStart, windowStart;
    bool dragging;
    internal PetWindow(ShiroContext owner)
    {
        this.owner = owner;
        Text = "Широ"; FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        AutoScaleMode = AutoScaleMode.None; ClientSize = new(192, 212); StartPosition = FormStartPosition.Manual; Cursor = Cursors.Hand;
    }
    internal void RestoreLocation(int? x, int? y)
    {
        var area = Screen.PrimaryScreen!.WorkingArea;
        Location = x.HasValue && y.HasValue ? new(x.Value, y.Value) : new(area.Right - Width - 32, area.Bottom - Height - 32);
        ClampLocation();
    }
    internal void ClampLocation()
    {
        var area = Screen.FromRectangle(Bounds).WorkingArea;
        Location = new(Math.Clamp(Left, area.Left, Math.Max(area.Left, area.Right - Width)), Math.Clamp(Top, area.Top, Math.Max(area.Top, area.Bottom - Height)));
    }
    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        float factor = DeviceDpi / 96f;
        ClientSize = new((int)Math.Round(192 * factor), (int)Math.Round(212 * factor));
        CreateSurface(Width, Height);
    }
    protected override void OnDpiChanged(DpiChangedEventArgs e)
    {
        base.OnDpiChanged(e);
        float factor = e.DeviceDpiNew / 96f;
        ClientSize = new((int)Math.Round(192 * factor), (int)Math.Round(212 * factor));
        CreateSurface(Width, Height); ClampLocation(); Render(owner.CurrentRow, owner.MotionSeconds);
    }
    internal void Render(int row, double seconds)
    {
        if (IsDisposed || !IsHandleCreated || !Visible) return;
        Present(g =>
        {
            g.ScaleTransform(Width / 192f, Height / 212f);
            rig.Draw(g, row, seconds, new(24, 0, 144, 156));
            DrawBadge(g);
        });
    }
    // The badge uses the head colours of the chosen scheme. With a current task it grows to two lines; a long title runs once after an action.
    void DrawBadge(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        var theme = owner.CurrentTheme; string? title = owner.ActiveTaskTitle; bool twoLines = !string.IsNullOrEmpty(title);
        var badge = twoLines ? new RectangleF(10, 158, 172, 50) : new RectangleF(22, 170, 148, 36);
        using (var path = Draw.RoundPath(badge, twoLines ? 16 : 18))
        {
            using var fill = new SolidBrush(theme.HeadBackground); g.FillPath(fill, path);
            using var edge = new Pen(Ink.A(theme.HeadInk, .12)); g.DrawPath(edge, path);
        }
        float lineMid = twoLines ? badge.Y + 17 : badge.Y + badge.Height / 2;
        Draw.Text(g, owner.BadgeTime, badge.X + 14, lineMid, Fonts.Display(16, 400), theme.HeadInk);
        Draw.Text(g, L.T(owner.Timer.State.Phase == "break" ? "break" : "focus"), badge.Right - 14, lineMid, Fonts.Text(11), theme.HeadMuted, alignRight: true, heavy: true);
        if (!twoLines) return;
        var font = Fonts.Text(12); var lane = new RectangleF(badge.X + 14, badge.Y + 28, badge.Width - 28, 16);
        var color = Ink.A(theme.HeadInk, .85);
        var saved = g.Save(); g.SetClip(lane);
        if (owner.MarqueeRunning)
        {
            float width = Draw.Measure(title!, font).Width, shift = (float)owner.MarqueeShift(width);
            Draw.Text(g, title!, lane.X - shift, lane.Y + lane.Height / 2, font, color);
            Draw.Text(g, title!, lane.X - shift + width + (float)ShiroContext.MarqueeGap, lane.Y + lane.Height / 2, font, color);
        }
        else Draw.Ellipsis(g, title!, lane, font, color);
        g.Restore(saved);
    }
    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button == MouseButtons.Right) { owner.ShowContextMenu(Cursor.Position); return; }
        if (e.Button != MouseButtons.Left) return;
        dragStart = Cursor.Position; windowStart = Location; dragging = false; Capture = true;
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        if (!Capture) return;
        var delta = Cursor.Position - (Size)dragStart;
        if (Math.Abs(delta.X) + Math.Abs(delta.Y) > 4) dragging = true;
        if (dragging) Location = windowStart + (Size)delta;
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        if (e.Button != MouseButtons.Left || !Capture) return;
        Capture = false;
        if (dragging) { ClampLocation(); owner.Save(); } else owner.TogglePanel();
    }
    protected override void Dispose(bool disposing) { if (disposing) rig.Dispose(); base.Dispose(disposing); }
}
