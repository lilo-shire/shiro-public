namespace Shiro;

public sealed class TaskEntry
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Title { get; set; } = "";
    public string SectionId { get; set; } = "";
    public bool Done { get; set; }
    public double FocusSeconds { get; set; }
    public int Pomodoros { get; set; }
    public double Remaining { get; set; } = -1;   // own focus time with a separate timer per task; -1 = fresh
    public string? Link { get; set; }
}

public sealed class TaskSection
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Title { get; set; } = "";
    public bool Collapsed { get; set; }
}

public sealed class TaskState
{
    public List<TaskEntry> Tasks { get; set; } = new();
    public List<TaskSection> Sections { get; set; } = new();
    public string? ActiveTaskId { get; set; }
    public double FocusAnchorRemaining { get; set; } = -1;
    public bool DoneCollapsed { get; set; } = true;
    public int Version { get; set; } = 6;
}

// Sections hold open tasks; finished tasks keep their section but are shown together in the done list.
// ActiveTaskId is the selected task. Same rules as the macOS ShiroTaskStore.
public sealed class TaskStore
{
    public TaskState State { get; }
    public int Revision { get; private set; }
    public IReadOnlyList<TaskEntry> Tasks => State.Tasks;
    public IReadOnlyList<TaskSection> Sections => State.Sections;
    public string? ActiveTaskId { get => State.ActiveTaskId; set => State.ActiveTaskId = value; }
    public double FocusAnchorRemaining { get => State.FocusAnchorRemaining; set => State.FocusAnchorRemaining = value; }
    public bool DoneCollapsed { get => State.DoneCollapsed; set => State.DoneCollapsed = value; }

    static string Trim(string? text, int limit)
    {
        text = (text ?? "").Trim();
        return text.Length > limit ? text[..limit] : text;
    }
    // Version 0.5 forced section titles to upper case; show them as normal words again.
    static string FromLegacy(string title)
    {
        if (title != title.ToUpperInvariant() || title == title.ToLowerInvariant()) return title;
        string lower = title.ToLowerInvariant();
        return char.ToUpperInvariant(lower[0]) + lower[1..];
    }

    public TaskStore(TaskState? state, IReadOnlyList<string>? defaultSections = null)
    {
        bool fresh = state == null;
        State = state ?? new();
        bool legacy = State.Version < 6;
        State.Sections = (State.Sections ?? new()).Where(s => s != null && !string.IsNullOrWhiteSpace(s.Title)).Take(24).ToList();
        foreach (var section in State.Sections)
        {
            section.Title = Trim(section.Title, 32);
            if (legacy) section.Title = FromLegacy(section.Title);
            if (string.IsNullOrWhiteSpace(section.Id)) section.Id = Guid.NewGuid().ToString("N");
        }
        if (fresh)
        {
            var titles = defaultSections ?? new[] { "Работа", "Личное" };
            var ids = new[] { "work", "personal" };
            for (int i = 0; i < titles.Count && i < 24; i++) State.Sections.Add(new() { Id = i < ids.Length ? ids[i] : Guid.NewGuid().ToString("N"), Title = Trim(titles[i], 32) });
        }
        State.Tasks = (State.Tasks ?? new()).Where(t => t != null && !string.IsNullOrWhiteSpace(t.Title)).Take(200).ToList();
        foreach (var task in State.Tasks)
        {
            task.Title = Trim(task.Title, 100);
            if (string.IsNullOrWhiteSpace(task.Id)) task.Id = Guid.NewGuid().ToString("N");
            task.FocusSeconds = double.IsFinite(task.FocusSeconds) ? Math.Max(0, task.FocusSeconds) : 0;
            task.Pomodoros = Math.Max(0, task.Pomodoros);
            task.Remaining = double.IsFinite(task.Remaining) && task.Remaining > 0 ? task.Remaining : -1;
            task.Link = string.IsNullOrWhiteSpace(task.Link) ? null : Trim(task.Link, 2000);
            if (Section(task.SectionId) == null)
            {
                // A task without a section gets the first one; with no sections at all a "Задачи" section is created.
                if (State.Sections.Count == 0) State.Sections.Add(new() { Title = "Задачи" });
                task.SectionId = State.Sections[0].Id;
            }
        }
        var active = Task(State.ActiveTaskId);
        State.ActiveTaskId = active != null && !active.Done ? active.Id : FirstOpen()?.Id;
        if (!double.IsFinite(State.FocusAnchorRemaining) || State.FocusAnchorRemaining < 0) State.FocusAnchorRemaining = -1;
        State.Version = 6;
    }
    void Changed() => Revision++;

    public TaskSection? Section(string? id) => id == null ? null : State.Sections.FirstOrDefault(s => s.Id == id);
    public TaskEntry? Task(string? id) => id == null ? null : State.Tasks.FirstOrDefault(t => t.Id == id);
    public List<TaskEntry> InSection(string id) => State.Tasks.Where(t => t.SectionId == id && !t.Done).Concat(State.Tasks.Where(t => t.SectionId == id && t.Done)).ToList();
    public List<TaskEntry> OpenIn(string id) => State.Tasks.Where(t => t.SectionId == id && !t.Done).ToList();
    public List<TaskEntry> DoneTasks() => Enumerable.Reverse(State.Tasks).Where(t => t.Done).ToList();   // newest first
    public TaskEntry? FirstOpen()
    {
        foreach (var section in State.Sections) { var t = OpenIn(section.Id).FirstOrDefault(); if (t != null) return t; }
        return null;
    }

    public string? Add(string title, string sectionId)
    {
        title = Trim(title, 100);
        if (title.Length == 0 || State.Tasks.Count >= 200 || Section(sectionId) == null) return null;
        var task = new TaskEntry { Title = title, SectionId = sectionId };
        State.Tasks.Add(task);
        State.ActiveTaskId ??= task.Id;
        Changed(); return task.Id;
    }
    public string? AddSection(string title)
    {
        title = Trim(title, 32);
        if (title.Length == 0 || State.Sections.Count >= 24) return null;
        var section = new TaskSection { Title = title };
        State.Sections.Add(section); Changed(); return section.Id;
    }
    public void ToggleSection(string id) { var s = Section(id); if (s == null) return; s.Collapsed = !s.Collapsed; Changed(); }
    public void ExpandSection(string id) { var s = Section(id); if (s == null || !s.Collapsed) return; s.Collapsed = false; Changed(); }
    public bool RenameSection(string id, string title)
    {
        var s = Section(id); title = Trim(title, 32);
        if (s == null || title.Length == 0) return false;
        s.Title = title; Changed(); return true;
    }
    public bool DeleteSection(string id)
    {
        var s = Section(id); if (s == null) return false;
        bool hadActive = Task(State.ActiveTaskId)?.SectionId == id;
        State.Tasks.RemoveAll(t => t.SectionId == id);
        State.Sections.Remove(s);
        if (hadActive) { State.ActiveTaskId = FirstOpen()?.Id; State.FocusAnchorRemaining = -1; }
        Changed(); return true;
    }
    public bool MoveSection(string id, int index)
    {
        var s = Section(id);
        if (s == null || State.Sections.Count < 2) return false;
        int old = State.Sections.IndexOf(s), next = Math.Clamp(index, 0, State.Sections.Count - 1);
        if (old == next) return false;
        State.Sections.RemoveAt(old); State.Sections.Insert(next, s); Changed(); return true;
    }
    public bool Toggle(string id)
    {
        var task = Task(id); if (task == null) return false;
        task.Done = !task.Done;
        // Moving the task to the end puts it last in its group: last finished, or last reopened.
        State.Tasks.Remove(task); State.Tasks.Add(task);
        if (task.Done && State.ActiveTaskId == id) { State.ActiveTaskId = FirstOpen()?.Id; State.FocusAnchorRemaining = -1; }
        if (!task.Done && State.ActiveTaskId == null) State.ActiveTaskId = id;
        Changed(); return task.Done;
    }
    public bool Rename(string id, string title)
    {
        var task = Task(id); title = Trim(title, 100);
        if (task == null || title.Length == 0) return false;
        task.Title = title; Changed(); return true;
    }
    public bool Delete(string id)
    {
        var task = Task(id); if (task == null) return false;
        bool active = State.ActiveTaskId == id;
        State.Tasks.Remove(task);
        if (active) { State.ActiveTaskId = FirstOpen()?.Id; State.FocusAnchorRemaining = -1; }
        Changed(); return true;
    }
    // Puts a task before another open task of a section (null: at the end of its open tasks); a finished task is reopened.
    public bool Move(string id, string sectionId, string? beforeId)
    {
        var task = Task(id);
        if (task == null || Section(sectionId) == null || beforeId == id) return false;
        bool reopened = task.Done;
        State.Tasks.Remove(task);
        task.SectionId = sectionId; task.Done = false;
        var before = Task(beforeId);
        int index;
        if (before != null && before.SectionId == sectionId && !before.Done) index = State.Tasks.IndexOf(before);
        else { var last = OpenIn(sectionId).LastOrDefault(); index = last != null ? State.Tasks.IndexOf(last) + 1 : State.Tasks.Count; }
        State.Tasks.Insert(index, task);
        if (reopened && State.ActiveTaskId == null) State.ActiveTaskId = id;
        Changed(); return true;
    }
    public bool SetLink(string id, string? link)
    {
        var task = Task(id); if (task == null) return false;
        link = Trim(link, 2000);
        task.Link = link.Length > 0 ? link : null; Changed(); return true;
    }
    public bool Select(string id)
    {
        var task = Task(id);
        if (task == null || task.Done || State.ActiveTaskId == id) return false;
        State.ActiveTaskId = id; State.FocusAnchorRemaining = -1; Changed(); return true;
    }
    public double RemainingOf(string? id) => Task(id)?.Remaining ?? -1;
    public void SetRemaining(string? id, double remaining)
    {
        var task = Task(id); if (task == null) return;
        task.Remaining = double.IsFinite(remaining) && remaining > 0 ? remaining : -1;
    }
    public void ToggleDoneCollapsed() { State.DoneCollapsed = !State.DoneCollapsed; Changed(); }
    public int ClearDone() { int removed = State.Tasks.RemoveAll(t => t.Done); if (removed > 0) Changed(); return removed; }
    public void BeginFocus(double remaining) => State.FocusAnchorRemaining = double.IsFinite(remaining) ? Math.Max(0, remaining) : -1;
    public void Credit(double remaining, bool completedPomodoro)
    {
        var task = Task(State.ActiveTaskId);
        if (task == null || State.FocusAnchorRemaining < 0 || !double.IsFinite(remaining)) return;
        double elapsed = Math.Max(0, State.FocusAnchorRemaining - Math.Max(0, remaining));
        if (elapsed > .01) task.FocusSeconds += elapsed;
        if (completedPomodoro) task.Pomodoros++;
        State.FocusAnchorRemaining = Math.Max(0, remaining); Changed();
    }
}
