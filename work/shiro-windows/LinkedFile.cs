using System.Text.RegularExpressions;

namespace Shiro;

// A task line read from a connected Markdown file ("- [ ] text" under "## Section").
public sealed class FileTask
{
    public string Section { get; set; } = "";   // "" before the first "##"
    public string Title { get; set; } = "";     // [text](url) → text, [[note]] → note; ⭐ and times are kept
    public string? Link { get; set; }
    public bool Done { get; set; }
    public string RawLine { get; set; } = "";   // the line as it is in the file, used to find it again
}

// Shiro reads the file, appends new "- [ ] text" lines and flips "[ ]" ↔ "[x]" of one task; nothing else is changed or removed.
// Same rules as the macOS ShiroLinkedFile.
public static class LinkedFile
{
    static readonly Regex TaskLine = new(@"^[-*+] \[([ xX])\] (.+)$");
    static readonly Regex MdLink = new(@"\[([^\]]+)\]\(([^)\s]+)\)");
    static readonly Regex Wiki = new(@"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]");
    static readonly Regex Bare = new(@"https?://\S+");

    static string? Heading(string line, out int level)
    {
        level = 0;
        while (level < line.Length && line[level] == '#') level++;
        if (level == 0 || level > 6 || line.Length <= level || line[level] != ' ') { level = 0; return null; }
        return line[level..].Trim();
    }
    // The day summary is not a list of tasks.
    static bool Hidden(string name)
    {
        string lower = name.ToLowerInvariant();
        return lower.StartsWith("итог дня") || lower.StartsWith("day summary");
    }
    static string[] Lines(string text) => text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');

    public static List<FileTask> Parse(string text, string? path)
    {
        var tasks = new List<FileTask>();
        string section = ""; bool hidden = false;
        foreach (string raw in Lines(text))
        {
            string? heading = Heading(raw, out int level);
            if (heading != null) { if (level >= 2) { section = heading; hidden = Hidden(heading); } continue; }
            if (hidden) continue;
            // Only top-level checkboxes; indented sub-items stay in the file untouched.
            var m = TaskLine.Match(raw);
            if (!m.Success) continue;
            string body = m.Groups[2].Value.Trim();
            string? link = null;
            var first = MdLink.Match(body);
            if (first.Success) link = first.Groups[2].Value;
            var note = Wiki.Match(body);
            if (link == null && note.Success && !string.IsNullOrEmpty(path))
            {
                // Opens the note in Obsidian; Obsidian resolves the name inside the vault.
                string target = Path.Combine(Path.GetDirectoryName(path) ?? "", note.Groups[1].Value + ".md");
                link = "obsidian://open?path=" + Uri.EscapeDataString(target);
            }
            if (link == null) { var url = Bare.Match(body); if (url.Success) link = url.Value; }
            string title = MdLink.Replace(body, "$1");
            title = Wiki.Replace(title, w => w.Groups[2].Success ? w.Groups[2].Value : w.Groups[1].Value);
            tasks.Add(new() { Section = section, Title = title, Link = link, Done = m.Groups[1].Value != " ", RawLine = raw });
        }
        return tasks;
    }

    // New task goes to the end of "## Всплыло за день" if the file has it, otherwise to the end of the first "##" section.
    public static string Append(string text, string title)
    {
        title = string.Join(" ", title.Split('\r', '\n')).Trim();
        if (title.Length == 0) return text;
        string newline = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(newline).ToList();
        int target = -1, first = -1;
        for (int i = 0; i < lines.Count; i++)
        {
            string? heading = Heading(lines[i], out int level);
            if (heading == null || level < 2) continue;
            if (first < 0) first = i;
            if (heading.ToLowerInvariant().StartsWith("всплыло за день")) { target = i; break; }
        }
        if (target < 0) target = first;
        string entry = "- [ ] " + title;
        if (target < 0)
        {
            while (lines.Count > 0 && lines[^1].Trim().Length == 0) lines.RemoveAt(lines.Count - 1);
            lines.Add(entry); lines.Add("");
            return string.Join(newline, lines);
        }
        int end = lines.Count;
        for (int i = target + 1; i < lines.Count; i++) if (Heading(lines[i], out _) != null) { end = i; break; }
        int insert = target + 1;
        for (int i = target + 1; i < end; i++) if (lines[i].Trim().Length > 0) insert = i + 1;
        lines.Insert(insert, entry);
        // Keep one blank line before the next heading, as in the original layout.
        if (insert + 1 < lines.Count && Heading(lines[insert + 1], out _) != null) lines.Insert(insert + 1, "");
        return string.Join(newline, lines);
    }

    // Returns null when the task line is no longer in the file.
    public static string? SetDone(string text, FileTask task, bool done)
    {
        if (task.RawLine.Length < 5) return null;
        string newline = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(newline);
        for (int i = 0; i < lines.Length; i++)
        {
            if (lines[i] != task.RawLine) continue;
            // "- [ ] …": the mark is the fourth character.
            lines[i] = lines[i][..3] + (done ? "x" : " ") + lines[i][4..];
            return string.Join(newline, lines);
        }
        return null;
    }

    // Shiro's own order for the file block, kept outside the file. order lists titles; sections maps a title to the group it was moved to.
    // Groups keep the file's order; inside a group known titles follow `order`, new ones go to the end.
    public static List<FileTask> Ordered(IReadOnlyList<FileTask> tasks, IReadOnlyList<string> order, IReadOnlyDictionary<string, string> sections)
    {
        var groups = new List<string>();
        foreach (var t in tasks) if (!groups.Contains(t.Section)) groups.Add(t.Section);
        var shown = new List<FileTask>();
        foreach (string group in groups)
        {
            var members = new List<(int key, FileTask task)>();
            for (int i = 0; i < tasks.Count; i++)
            {
                var t = tasks[i];
                string place = sections.TryGetValue(t.Title, out var moved) && groups.Contains(moved) ? moved : t.Section;
                if (place != group) continue;
                int known = order.ToList().IndexOf(t.Title);
                members.Add((known < 0 ? 1000000 + i : known, new FileTask { Section = place, Title = t.Title, Link = t.Link, Done = t.Done, RawLine = t.RawLine }));
            }
            shown.AddRange(members.OrderBy(m => m.key).Select(m => m.task));
        }
        return shown;
    }
    // The new title order after moving `moved` before `before` (null: to the end of `section`) in the shown list.
    public static List<string> OrderAfterMoving(FileTask moved, FileTask? before, string section, IReadOnlyList<FileTask> shown)
    {
        var list = shown.Where(t => !ReferenceEquals(t, moved)).ToList();
        int index = before != null ? list.FindIndex(t => ReferenceEquals(t, before)) : -1;
        if (index < 0)
        {
            index = list.Count;
            for (int i = 0; i < list.Count; i++) if (list[i].Section == section) index = i + 1;
        }
        list.Insert(index, moved);
        return list.Select(t => t.Title).ToList();
    }
}
