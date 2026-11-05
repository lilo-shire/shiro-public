using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;

namespace Shiro;

internal interface IPanelHost
{
    TimerModel Timer { get; }
    TaskStore Store { get; }
    Theme Theme { get; }
    string Scope { get; }
    double UiScale { get; }
    string? FileName { get; }
    IReadOnlyList<FileTask> FileTasks { get; }
    bool FileMissing { get; }
    bool FileCollapsed { get; }
    int FileIndex { get; }
    string? ActiveFileTitle { get; }
    void ToggleTimer(); void ResetTimer(); void SwitchPhase(string phase);
    void SelectTask(string id); void ToggleTask(string id); void AddTask(string title, string sectionId); string? AddSection(string title);
    void RenameTask(string id, string title); void RenameSection(string id, string title); void DeleteTask(string id); void DeleteSection(string id);
    void MoveTask(string id, string sectionId, string? beforeId); void SetLink(string id, string link);
    void ToggleDoneList(); void ClearDone(); void ToggleSection(string id); void ExpandSection(string id); void ReorderBlocks(List<string> keys);
    void AddTaskToFile(string title); void ImportFileTask(int index, string sectionId, string? beforeId); void ImportFileTaskMenu(int index, Point screen);
    void ToggleFileBlock(); void ToggleFileTask(int index); void SelectFileTask(int index); void MoveFileTask(int index, int beforeIndex, string section);
    void ShowSettings(); void ClosePanel(); void ContentChanged();
}

// Drawing helpers on the 24-unit icon grid and for text, shared by the window, the settings and the pet badge.
internal static class Draw
{
    static readonly Bitmap measureBitmap = new(1, 1);
    static readonly Graphics measure = Graphics.FromImage(measureBitmap);
    static readonly StringFormat Typographic = MakeFormat();
    static StringFormat MakeFormat() { var f = (StringFormat)StringFormat.GenericTypographic.Clone(); f.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces | StringFormatFlags.NoWrap; return f; }

    internal static SizeF Measure(string text, Font font) => measure.MeasureString(text, font, PointF.Empty, Typographic);
    internal static float WrappedHeight(string text, Font font, float width)
    {
        using var format = new StringFormat(StringFormat.GenericTypographic) { Trimming = StringTrimming.Word };
        return (float)Math.Ceiling(measure.MeasureString(text.Length > 0 ? text : "M", font, new SizeF(Math.Max(20, width), 10000), format).Height);
    }
    // Text centred on midY; weight ≥ 550 is drawn a little heavier (Onest has a single embedded weight).
    internal static float Text(Graphics g, string text, float x, float midY, Font font, Color color, bool alignRight = false, bool heavy = false, float tracking = 0)
    {
        var size = Measure(text, font);
        float width = size.Width + tracking * Math.Max(0, text.Length - 1);
        float left = alignRight ? x - width : x, top = midY - size.Height / 2;
        if (tracking > 0)
        {
            float cx = left;
            foreach (char c in text) { Glyphs(g, c.ToString(), cx, top, font, color, heavy); cx += Measure(c.ToString(), font).Width + tracking; }
        }
        else Glyphs(g, text, left, top, font, color, heavy);
        return width;
    }
    static void Glyphs(Graphics g, string text, float x, float y, Font font, Color color, bool heavy)
    {
        if (!heavy || Fonts.HasBold && font.Bold)
        {
            using var brush = new SolidBrush(color);
            g.DrawString(text, font, brush, x, y, Typographic);
            return;
        }
        using var path = new GraphicsPath();
        path.AddString(text, font.FontFamily, (int)FontStyle.Regular, font.Size, new PointF(x, y), Typographic);
        using var fill = new SolidBrush(color);
        using var pen = new Pen(color, font.Size * .045f) { LineJoin = LineJoin.Round };
        var mode = g.SmoothingMode; g.SmoothingMode = SmoothingMode.AntiAlias;
        g.FillPath(fill, path); g.DrawPath(pen, path);
        g.SmoothingMode = mode;
    }
    internal static void Wrapped(Graphics g, string text, RectangleF rect, Font font, Color color, bool heavy, bool strike)
    {
        using var format = new StringFormat(StringFormat.GenericTypographic) { Trimming = StringTrimming.Word };
        if (heavy && !(Fonts.HasBold && font.Bold))
        {
            using var path = new GraphicsPath();
            path.AddString(text, font.FontFamily, (int)FontStyle.Regular, font.Size, rect, format);
            using var fill = new SolidBrush(color);
            using var pen = new Pen(color, font.Size * .045f) { LineJoin = LineJoin.Round };
            g.FillPath(fill, path); g.DrawPath(pen, path);
        }
        else { using var brush = new SolidBrush(color); g.DrawString(text, font, brush, rect, format); }
        if (!strike) return;
        // A line through each wrapped line of the title.
        float line = font.GetHeight(g), y = rect.Y + line * .55f, rows = Math.Max(1, (float)Math.Round(WrappedHeight(text, font, rect.Width) / line));
        using var strikePen = new Pen(color, 1.2f);
        for (int i = 0; i < rows; i++)
        {
            float w = i < rows - 1 ? rect.Width : Math.Min(rect.Width, Measure(text, font).Width - rect.Width * (rows - 1));
            if (rows == 1) w = Math.Min(rect.Width, Measure(text, font).Width);
            g.DrawLine(strikePen, rect.X, y + i * line, rect.X + Math.Max(8, w), y + i * line);
        }
    }
    internal static void Ellipsis(Graphics g, string text, RectangleF rect, Font font, Color color)
    {
        using var format = new StringFormat(StringFormat.GenericTypographic) { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap, LineAlignment = StringAlignment.Center };
        using var brush = new SolidBrush(color);
        g.DrawString(text, font, brush, rect, format);
    }
    internal static void Circle(Graphics g, RectangleF r, Color c) { using var b = new SolidBrush(c); g.FillEllipse(b, r); }
    internal static void Ring(Graphics g, RectangleF r, Color c, float width, bool dashed = false)
    {
        using var pen = new Pen(c, width);
        if (dashed) pen.DashPattern = new[] { 1.5f, 1.5f };
        g.DrawEllipse(pen, r.X + width / 2, r.Y + width / 2, r.Width - width, r.Height - width);
    }
    internal static void Round(Graphics g, RectangleF r, float radius, Color c)
    {
        using var path = RoundPath(r, radius); using var b = new SolidBrush(c); g.FillPath(b, path);
    }
    internal static GraphicsPath RoundPath(RectangleF r, float radius)
    {
        var path = new GraphicsPath();
        float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
        if (d <= 0) { path.AddRectangle(r); return path; }
        path.AddArc(r.X, r.Y, d, d, 180, 90); path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure(); return path;
    }
    internal static void Rect(Graphics g, RectangleF r, Color c) { using var b = new SolidBrush(c); g.FillRectangle(b, r); }

    // Icons drawn on a 24-unit grid centred in rect; weight is in grid units, as an SVG stroke-width.
    internal static void Icon(Graphics g, string name, RectangleF rect, float size, Color color, float weight)
    {
        float s = size / 24f, ox = rect.X + rect.Width / 2 - size / 2, oy = rect.Y + rect.Height / 2 - size / 2;
        PointF P(float x, float y) => new(ox + x * s, oy + y * s);
        using var pen = new Pen(color, weight * s) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        void Line(params float[] xy) { var pts = new PointF[xy.Length / 2]; for (int i = 0; i < pts.Length; i++) pts[i] = P(xy[i * 2], xy[i * 2 + 1]); g.DrawLines(pen, pts); }
        switch (name)
        {
            case "plus": Line(12, 5, 12, 19); Line(5, 12, 19, 12); break;
            case "x": Line(18, 6, 6, 18); Line(6, 6, 18, 18); break;
            case "chevDown": Line(6, 9, 12, 15, 18, 9); break;
            case "chevRight": Line(9, 6, 15, 12, 9, 18); break;
            case "check": Line(20, 6, 9, 17, 4, 12); break;
            case "arrow": Line(5, 12, 19, 12); Line(13, 6, 19, 12, 13, 18); break;
            case "more":
                using (var b = new SolidBrush(color)) foreach (float x in new[] { 5f, 12f, 19f }) { var c = P(x, 12); g.FillEllipse(b, c.X - 1.6f * s, c.Y - 1.6f * s, 3.2f * s, 3.2f * s); }
                break;
            case "reset":
                g.DrawArc(pen, ox + 3 * s, oy + 3 * s, 18 * s, 18 * s, 180, 312);
                Line(3, 3, 3, 8, 8, 8); break;
            case "sliders":
                Line(4, 21, 4, 14); Line(4, 10, 4, 3); Line(12, 21, 12, 12); Line(12, 8, 12, 3); Line(20, 21, 20, 16); Line(20, 12, 20, 3);
                Line(1, 14, 7, 14); Line(9, 8, 15, 8); Line(17, 16, 23, 16); break;
            case "doc":
                Line(14, 3, 6, 3, 6, 21, 18, 21, 18, 7, 14, 3); Line(14, 3, 14, 7, 18, 7); Line(9, 12, 15, 12); Line(9, 16, 15, 16); break;
            case "link":
                using (var path = new GraphicsPath())
                {
                    path.AddBezier(P(10, 13), P(11.6f, 15.2f), P(14, 15), P(15.5f, 13.5f)); path.AddLine(P(15.5f, 13.5f), P(19, 10));
                    path.AddBezier(P(19, 10), P(20.5f, 8.4f), P(15.6f, 3.5f), P(14, 5)); path.AddLine(P(14, 5), P(12.5f, 6.5f));
                    path.StartFigure();
                    path.AddBezier(P(14, 11), P(12.4f, 8.8f), P(10, 9), P(8.5f, 10.5f)); path.AddLine(P(8.5f, 10.5f), P(5, 14));
                    path.AddBezier(P(5, 14), P(3.5f, 15.6f), P(8.4f, 20.5f), P(10, 19)); path.AddLine(P(10, 19), P(11.5f, 17.5f));
                    g.DrawPath(pen, path);
                }
                break;
        }
    }
    internal static void Play(Graphics g, RectangleF r, Color c)
    {
        using var b = new SolidBrush(c);
        g.FillPolygon(b, new[] { new PointF(r.X + r.Width * .21f, r.Y + r.Height * .1f), new PointF(r.X + r.Width * .21f, r.Y + r.Height * .9f), new PointF(r.X + r.Width * .9f, r.Y + r.Height / 2) });
    }
    internal static void Pause(Graphics g, RectangleF r, Color c)
    {
        float w = r.Width * .21f, h = r.Height * .75f, y = r.Y + r.Height / 2 - h / 2;
        Rect(g, new(r.X + r.Width * .21f, y, w, h), c); Rect(g, new(r.X + r.Width * .58f, y, w, h), c);
    }
}

internal sealed class PanelForm : Form
{
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam);

    internal const float Width0 = 560;
    const float BarH = 46, HeadH = 154, TheadH = 44, SecHeadH = 46, RowH = 40, TitleX = 84;

    sealed class Hit { public RectangleF Rect; public string Action = ""; public string? Ident; }
    sealed class Item { public string Kind = ""; public string? SectionId, TaskId; public int Band; public float Y, H, TitleH; }
    sealed class Block { public string? SectionId; public int Band; public float Top, Bottom; public bool Collapsed; }
    sealed class Drop { public string? SectionId, BeforeId; public float LineY = float.NaN; }

    readonly IPanelHost host;
    readonly List<Hit> hits = new();
    List<Item> items = new();
    List<Block> blocks = new();
    float layoutHeight, scrollY;
    string? hoverKey;
    string? editKind, editTarget;   // task / section / renameTask / renameSection / link / fileTask
    TextBox? editor;
    RectangleF editorRect;
    bool finishingEdit;
    string? pressAction, pressIdent;
    PointF pressPoint;
    string? dragSection, dragTask;
    bool dragging;
    int dropGap = -1;
    Drop? drop;
    string? toast;
    DateTime toastUntil;
    readonly System.Windows.Forms.Timer toastTimer = new() { Interval = 2300 };

    internal PanelForm(IPanelHost host)
    {
        this.host = host;
        Text = "Широ"; FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; StartPosition = FormStartPosition.Manual;
        KeyPreview = true; DoubleBuffered = true; AutoScaleMode = AutoScaleMode.None;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        toastTimer.Tick += (_, _) => { toastTimer.Stop(); Invalidate(); };
        Deactivate += (_, _) => { if (editKind != null) CommitEdit(false); };
    }
    protected override CreateParams CreateParams { get { var p = base.CreateParams; p.ClassStyle |= 0x20000; p.ExStyle |= 0x80; return p; } }   // drop shadow, tool window
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int round = 2; // DWMWCP_ROUND: Windows 11 draws smooth rounded corners; Windows 10 ignores it.
        try { DwmSetWindowAttribute(Handle, 33, ref round, sizeof(int)); } catch (DllNotFoundException) { }
    }

    float K => (float)(host.UiScale * DeviceDpi / 96.0);
    SizeF Logical => new(ClientSize.Width / K, ClientSize.Height / K);
    RectangleF ToView(RectangleF r) => new(r.X * K, r.Y * K, r.Width * K, r.Height * K);
    PointF LogicalPoint(Point p) => new(p.X / K, p.Y / K);
    internal int PreferredWidth => (int)Math.Round(Width0 * K);
    internal int PreferredHeight { get { BuildLayout(); return (int)Math.Ceiling((HeadH + layoutHeight) * K); } }
    float VisibleListHeight => Math.Max(0, Logical.Height - HeadH);
    void ClampScroll() { BuildLayout(); scrollY = Math.Max(0, Math.Min(scrollY, layoutHeight - VisibleListHeight)); }

    internal void Reload()
    {
        if (editKind != null && !EditTargetExists()) EndEdit();
        ClampScroll(); Invalidate(); host.ContentChanged();
    }
    internal void RefreshTimer() => Invalidate(new Rectangle(0, 0, ClientSize.Width, (int)Math.Ceiling(HeadH * K)));
    internal void ShowToast(string text) { toast = text; toastUntil = DateTime.UtcNow.AddSeconds(2.2); toastTimer.Stop(); toastTimer.Start(); Invalidate(); }
    bool EditTargetExists() => editKind switch
    {
        "section" => true,
        "fileTask" => host.FileName != null,
        "task" or "renameSection" => host.Store.Section(editTarget) != null,
        _ => host.Store.Task(editTarget) != null
    };
    static string TimeText(double seconds) { int s = (int)Math.Ceiling(Math.Max(0, seconds) - .0001); return $"{s / 60:00}:{s % 60:00}"; }

    // ---------- Layout (list coordinates: 0 is the top of the "Tasks" heading) ----------
    Font TitleFont => Fonts.Text(15);
    float TaskTimeWidth => host.Scope == "task" ? Draw.Measure("00:00", Fonts.Display(12, 400)).Width + 10 : 0;
    float TitleWidth(bool done) => Width0 - 10 - 30 - 8 - (done ? 90 : TaskTimeWidth) - TitleX;
    float FileTitleWidth => Width0 - 10 - 30 - 8 - TitleX;
    float EditorWidth(string? kind) => kind == "section" ? Width0 - 18 - 72 - 18 : kind == "renameSection" ? Width0 - 8 - 72 - 50 : Width0 - 10 - 72 - TitleX;
    float FormHeight => Math.Max(RowH, Draw.WrappedHeight(editor?.Text ?? "", TitleFont, EditorWidth(editKind) - 4) + 18);
    float RowHeight(TaskEntry task, out float titleH)
    {
        titleH = Draw.WrappedHeight(task.Title, TitleFont, TitleWidth(task.Done));
        return Math.Max(RowH, titleH + 20) + (string.IsNullOrEmpty(task.Link) ? 0 : 18);
    }
    void BuildLayout()
    {
        var list = new List<Item>(); var blockList = new List<Block>();
        Item Add(string kind, string? sid, string? tid, int band, float y0, float h) { var i = new Item { Kind = kind, SectionId = sid, TaskId = tid, Band = band, Y = y0, H = h }; list.Add(i); return i; }
        float y = TheadH;
        if (editKind == "section") { Add("sectionForm", null, null, 0, y, FormHeight); y += FormHeight; }
        void FileBlock()
        {
            if (host.FileName == null) return;
            var block = new Block { SectionId = "file", Band = -2, Top = y, Collapsed = host.FileCollapsed };
            Add("fileHeader", "file", null, -2, y, SecHeadH); y += SecHeadH;
            if (editKind == "fileTask") { Add("taskForm", "file", null, -2, y, FormHeight); y += FormHeight; }
            if (!block.Collapsed)
            {
                if (host.FileMissing || host.FileTasks.Count == 0) { Add("fileEmpty", "file", null, -2, y, RowH); y += RowH; }
                string? last = null;
                for (int i = 0; i < host.FileTasks.Count; i++)
                {
                    var task = host.FileTasks[i];
                    if (task.Section.Length > 0 && task.Section != last) { Add("fileSection", "file", "file:" + i, -2, y, 30); y += 30; }
                    last = task.Section;
                    float h = Draw.WrappedHeight(task.Title, TitleFont, FileTitleWidth);
                    var row = Add("fileRow", "file", "file:" + i, -2, y, Math.Max(RowH, h + 20) + (string.IsNullOrEmpty(task.Link) ? 0 : 18));
                    row.TitleH = h; y += row.H;
                }
            }
            y += 4; block.Bottom = y; blockList.Add(block);
        }
        var sections = host.Store.Sections;
        int fileAt = Math.Clamp(host.FileIndex, 0, sections.Count);
        for (int i = 0; i < sections.Count; i++)
        {
            if (i == fileAt) FileBlock();
            var section = sections[i];
            var block = new Block { SectionId = section.Id, Band = i, Top = y, Collapsed = section.Collapsed };
            Add("header", section.Id, null, i, y, SecHeadH); y += SecHeadH;
            if (editKind == "task" && editTarget == section.Id) { Add("taskForm", section.Id, null, i, y, FormHeight); y += FormHeight; }
            if (!block.Collapsed)
            {
                var open = host.Store.OpenIn(section.Id);
                foreach (var task in open)
                {
                    bool editing = (editKind == "renameTask" || editKind == "link") && editTarget == task.Id;
                    float titleH = 0, h = editing ? FormHeight : RowHeight(task, out titleH);
                    var row = Add(editing ? "taskForm" : "row", section.Id, task.Id, i, y, h); row.TitleH = titleH; y += h;
                }
                if (open.Count == 0 && !(editKind == "task" && editTarget == section.Id)) { Add("empty", section.Id, null, i, y, RowH); y += RowH; }
            }
            y += 4; block.Bottom = y; blockList.Add(block);
        }
        if (fileAt >= sections.Count) FileBlock();
        var done = host.Store.DoneTasks();
        if (done.Count > 0 || (dragging && dragTask != null && !dragTask.StartsWith("file:")))
        {
            var block = new Block { Band = -1, Top = y, Collapsed = host.Store.DoneCollapsed };
            Add("doneHeader", null, null, -1, y, SecHeadH); y += SecHeadH;
            if (!block.Collapsed) foreach (var task in done) { float h = RowHeight(task, out float th); var row = Add("doneRow", task.SectionId, task.Id, -1, y, h); row.TitleH = th; y += h; }
            y += 4; block.Bottom = y; blockList.Add(block);
        }
        y += 4;
        items = list; blocks = blockList; layoutHeight = y;
    }

    Color FillFor(int band) => band == -2 ? host.Theme.Popover : band < 0 ? Ink.Blend(host.Theme.Background, host.Theme.Ink, .06) : host.Theme.BandFill(band);
    Color InkFor(int band) => band == -2 ? host.Theme.PopoverInk : band < 0 ? host.Theme.Ink : host.Theme.BandInk(band);
    string Key(string action, string? ident) => action + "|" + (ident ?? "");
    bool Hovered(string action, string? ident) => hoverKey == Key(action, ident);
    void AddHit(RectangleF r, string action, string? ident = null) => hits.Add(new Hit { Rect = r, Action = action, Ident = ident });

    // ---------- Drawing ----------
    protected override void OnPaint(PaintEventArgs e)
    {
        hits.Clear();
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit; g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.ScaleTransform(K, K);
        float W = Width0, H = Logical.Height;
        Draw.Rect(g, new(0, 0, W, H), host.Theme.Background);
        DrawHead(g, W);
        var state = g.Save();
        g.SetClip(new RectangleF(0, HeadH, W, H - HeadH));
        DrawList(g, HeadH - scrollY, H);
        g.Restore(state);
        if (toast != null && DateTime.UtcNow < toastUntil)
        {
            var font = Fonts.Text(14); var size = Draw.Measure(toast, font);
            var pill = new RectangleF((W - size.Width) / 2 - 16, H - 52, size.Width + 32, 36);
            Draw.Round(g, pill, 18, host.Theme.Ink);
            Draw.Text(g, toast, pill.X + 16, pill.Y + 18, font, host.Theme.Background);
        }
        if (editor != null) PositionEditor();
    }

    void DrawHead(Graphics g, float W)
    {
        var t = host.Theme; Color ink = t.HeadInk, bg = t.HeadBackground;
        Draw.Rect(g, new(0, 0, W, HeadH), bg);
        Draw.Text(g, "SHIRO", 18, BarH / 2 + 1, Fonts.Display(14, 400), ink, tracking: 2.3f);
        var close = new RectangleF(W - 10 - 32, 7, 32, 32); var settings = new RectangleF(close.X - 34, 7, 32, 32);
        foreach (var (action, rect, icon) in new[] { ("settings", settings, "sliders"), ("close", close, "x") })
        {
            bool hover = Hovered(action, null);
            if (hover) Draw.Circle(g, rect, Ink.A(ink, .12));
            Draw.Icon(g, icon, rect, 16, hover ? ink : t.HeadMuted, 2);
            AddHit(rect, action);
        }
        // Ruler: one tick per minute, bigger every five; the black mark is "now".
        var timer = host.Timer; double now = ShiroContext.Now;
        double total = timer.DurationOf(timer.State.Phase), left = timer.RemainingAt(now);
        double frac = total > 0 ? Math.Clamp((total - left) / total, 0, 1) : 0;
        int minutes = Math.Clamp((int)Math.Round(total / 60), 1, 60);
        float rx = 20, rw = W - 40, top = 48;
        Draw.Round(g, new(rx, top + 4, (float)(rw * frac), 18), 3, Ink.A(ink, .08));
        for (int i = 0; i <= minutes; i++)
        {
            bool major = i % 5 == 0;
            float x = (float)Math.Round(rx + rw * i / minutes) - (i == minutes ? 1 : 0);
            Draw.Rect(g, new(x, top + 22 - (major ? 16 : 9), 1, major ? 16 : 9), Ink.A(ink, major ? .46 : .24));
        }
        Draw.Round(g, new((float)(rx + rw * frac - 1), top + 1, 3, 24), 1.5f, ink);

        float mid = 112;
        var play = new RectangleF(18, mid - 17, 30, 34);
        if (timer.State.Running) Draw.Pause(g, play, ink); else Draw.Play(g, play, ink);
        float timeW = Draw.Text(g, TimeText(left), 64, mid, Fonts.Display(50, 300), ink);
        AddHit(new(10, mid - 26, 64 + timeW, 52), "toggle");
        Draw.Text(g, "/" + minutes, 64 + timeW + 6, mid - 18, Fonts.Text(13), t.HeadMuted);

        var reset = new RectangleF(W - 18 - 46, mid - 23, 46, 46);
        if (timer.State.Running) Draw.Ring(g, RectangleF.Inflate(reset, 4.5f, 4.5f), Ink.A(ink, .3), 1);
        Draw.Circle(g, reset, Hovered("reset", null) ? Ink.A(ink, .85) : ink);
        Draw.Icon(g, "reset", reset, 18, bg, 2);
        AddHit(reset, "reset");
        var modeFont = Fonts.Text(14); float mx = reset.X - 16;
        foreach (string phase in new[] { "break", "work" })
        {
            string label = L.T(phase == "work" ? "focus" : "break");
            bool active = timer.State.Phase == phase;
            float w = Draw.Text(g, label, mx, mid, modeFont, active ? ink : Ink.A(ink, Hovered("phase", phase) ? .6 : .3), alignRight: true, heavy: true);
            AddHit(new(mx - w - 6, mid - 16, w + 12, 32), "phase", phase);
            mx -= w + 14;
        }
    }

    void RoundButton(Graphics g, string icon, RectangleF r, string action, string? ident, Color ink, double baseAlpha)
    {
        double alpha = Hovered(action, ident) ? Math.Max(.12, baseAlpha * 2) : baseAlpha;
        if (alpha > 0) Draw.Circle(g, r, Ink.A(ink, alpha));
        Draw.Icon(g, icon, r, 16, ink, 2);
        AddHit(r, action, ident);
    }
    void FormRow(Graphics g, RectangleF row, float inputX, string? marker, Color ink, Color fill)
    {
        float firstMid = row.Y + 20;
        var cancel = new RectangleF(row.Right - 28, firstMid - 14, 28, 28); var ok = new RectangleF(cancel.X - 34, cancel.Y, 28, 28);
        Draw.Circle(g, ok, Hovered("formOK", null) ? Ink.A(ink, .85) : ink); Draw.Icon(g, "check", ok, 15, fill, 3);
        if (Hovered("formCancel", null)) Draw.Circle(g, cancel, Ink.A(ink, .1));
        Draw.Icon(g, "x", cancel, 15, ink, 2.4f);
        AddHit(ok, "formOK"); AddHit(cancel, "formCancel");
        var mark = new RectangleF(54, firstMid - 10, 20, 20);
        if (marker == "dash") Draw.Ring(g, RectangleF.Inflate(mark, -1, -1), Ink.A(ink, .4), 2, true);
        else if (marker == "link") Draw.Icon(g, "link", mark, 16, Ink.A(ink, .7), 2);
        else if (marker == "circle") Draw.Ring(g, RectangleF.Inflate(mark, -1, -1), ink, 2);
        float width = EditorWidth(editKind), textH = Math.Max(22, Draw.WrappedHeight(editor?.Text ?? "", TitleFont, width - 4));
        var input = new RectangleF(inputX, row.Y + 9, width, textH);
        Draw.Rect(g, new(input.X, input.Bottom + 2, input.Width, 1.5f), editor?.Focused == true ? ink : Ink.A(ink, .28));
        editorRect = input;
        if (editor != null) { editor.BackColor = fill; editor.ForeColor = ink; }
    }
    static string LinkLabel(string link)
    {
        string text = link.Split('?')[0];
        try { text = Uri.UnescapeDataString(text); } catch (UriFormatException) { }
        foreach (string prefix in new[] { "https://", "http://", "www." }) if (text.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) text = text[prefix.Length..];
        return text;
    }

    void DrawList(Graphics g, float top, float H)
    {
        var t = host.Theme; float W = Width0;
        BuildLayout();
        bool editorPlaced = false;
        float mid = top + 24;
        float w = Draw.Text(g, L.T("tasks"), 18, mid, Fonts.Text(15), t.Ink, heavy: true);
        int open = host.Store.Tasks.Count(x => !x.Done);
        Draw.Text(g, L.Active(open), 18 + w + 8, mid, Fonts.Text(13), t.Muted);
        var addFont = Fonts.Text(14); var addSize = Draw.Measure(L.T("addSection"), addFont);
        var add = new RectangleF(W - 18 - addSize.Width - 20, mid - 14, addSize.Width + 20, 28);
        bool addHover = Hovered("addSection", null);
        if (addHover) Draw.Round(g, add, 14, Ink.A(t.Ink, .07));
        Draw.Text(g, L.T("addSection"), add.X + 10, mid, addFont, addHover ? t.Ink : t.Muted);
        AddHit(add, "addSection");

        // Block fills; the last one runs to the bottom edge.
        for (int b = 0; b < blocks.Count; b++)
        {
            var block = blocks[b];
            float bottom = b + 1 == blocks.Count ? Math.Max(top + block.Bottom, H) + 4 : top + block.Bottom;
            Draw.Rect(g, new(0, top + block.Top, W, bottom - top - block.Top), FillFor(block.Band));
            bool target = dragging && dragTask != null && drop != null && float.IsNaN(drop.LineY) && block.SectionId == drop.SectionId;
            if (target) Draw.Rect(g, new(0, top + block.Top, W, bottom - top - block.Top), Ink.A(InkFor(block.Band), .10));
        }

        foreach (var item in items)
        {
            float y = top + item.Y;
            if (y > H + 10 || y + item.H < HeadH - 10) continue;
            Color ink = InkFor(item.Band), fill = FillFor(item.Band);
            bool faded = dragging && ((dragSection != null && dragSection == item.SectionId && item.Band != -1) || (item.TaskId != null && item.TaskId == dragTask));
            GraphicsContainer? fade = null;
            if (faded) { ink = Ink.A(ink, .35); fade = g.BeginContainer(); }
            var section = host.Store.Section(item.SectionId);
            var task = host.Store.Task(item.TaskId);
            switch (item.Kind)
            {
                case "sectionForm":
                    FormRow(g, new(18, y, W - 36, item.H), 18, null, t.Ink, t.Background); editorPlaced = true; break;
                case "fileHeader":
                {
                    float hm = y + 23;
                    var chev = new RectangleF(W - 8 - 30, hm - 15, 30, 30); var plus = new RectangleF(chev.X - 33, chev.Y, 30, 30);
                    Draw.Circle(g, new(14, hm - 13, 26, 26), Ink.A(ink, .08));
                    Draw.Icon(g, "doc", new(14, hm - 13, 26, 26), 15, Ink.A(ink, .75), 2);
                    var nameFont = Fonts.Text(15); string name = host.FileName ?? "";
                    float nameW = Math.Min(Draw.Measure(name, nameFont).Width, plus.X - 12 - 50 - 40);
                    Draw.Ellipsis(g, name, new(50, hm - 12, nameW + 4, 24), nameFont, ink);
                    if (!host.FileMissing) Draw.Text(g, host.FileTasks.Count(x => !x.Done).ToString(), 50 + nameW + 10, hm, Fonts.Text(12), Ink.A(ink, .55));
                    AddHit(new(0, y, plus.X - 4, SecHeadH), "fileHeader");
                    RoundButton(g, "plus", plus, "fileAdd", null, ink, .07);
                    RoundButton(g, host.FileCollapsed ? "chevRight" : "chevDown", chev, "fileToggle", null, ink, .07);
                    break;
                }
                case "fileSection":
                {
                    int index = int.Parse(item.TaskId![5..]);
                    Draw.Ellipsis(g, host.FileTasks[index].Section.ToUpperInvariant(), new(54, y + 8, W - 74, 18), Fonts.Text(11), Ink.A(ink, .45));
                    break;
                }
                case "fileEmpty":
                    Draw.Rect(g, new(52, y, W - 62, 1), Ink.A(ink, .10));
                    Draw.Text(g, L.T(host.FileMissing ? "fileMissing" : "fileEmpty"), 54, y + RowH / 2, Fonts.Text(14), Ink.A(ink, .55));
                    break;
                case "fileRow":
                {
                    int index = int.Parse(item.TaskId![5..]); var ft = host.FileTasks[index];
                    float firstMid = y + 20; bool selected = !ft.Done && ft.Title == host.ActiveFileTitle;
                    AddHit(new(0, y, W - 10 - 30, item.H), "fileRow", item.TaskId);
                    if (Hovered("fileRow", item.TaskId) || Hovered("import", item.TaskId)) Draw.Rect(g, new(52, y, W - 62, item.H), Ink.A(ink, .04));
                    Draw.Rect(g, new(52, y, W - 62, 1), Ink.A(ink, .10));
                    if (selected) { var go = new RectangleF(14, firstMid - 12, 24, 24); Draw.Circle(g, go, ink); Draw.Icon(g, "arrow", go, 14, fill, 2.6f); }
                    // The circle marks the task done right in the file ("[ ]" ↔ "[x]").
                    var mark = new RectangleF(54, firstMid - 10, 20, 20);
                    if (ft.Done) { Draw.Circle(g, mark, Ink.A(ink, .5)); Draw.Icon(g, "check", mark, 12, fill, 3); }
                    else Draw.Ring(g, RectangleF.Inflate(mark, -1, -1), Ink.A(ink, Hovered("fileCheck", item.TaskId) ? 1 : .75), 2);
                    AddHit(RectangleF.Inflate(mark, 6, 8), "fileCheck", item.TaskId);
                    bool inShiro = host.Store.Tasks.Any(x => x.Title == ft.Title);
                    var button = new RectangleF(W - 10 - 30, firstMid - 15, 30, 30);
                    if (inShiro) Draw.Icon(g, "check", button, 14, Ink.A(ink, .4), 2);
                    else RoundButton(g, "plus", button, "import", item.TaskId, ink, 0);
                    Draw.Wrapped(g, ft.Title, new(TitleX, y + 10, FileTitleWidth, item.TitleH + 2), TitleFont, selected ? ink : Ink.A(ink, ft.Done || inShiro ? .5 : .9), selected, ft.Done);
                    if (!string.IsNullOrEmpty(ft.Link))
                    {
                        float ly = y + 10 + item.TitleH + 9; bool hover = Hovered("fileLink", item.TaskId);
                        string label = ft.Link.StartsWith("obsidian://") ? "Obsidian" : LinkLabel(ft.Link);
                        Draw.Icon(g, "link", new(TitleX - 1, ly - 7, 14, 14), 13, Ink.A(ink, hover ? .9 : .5), 2);
                        var f = Fonts.Text(12); float lw = Math.Min(Draw.Measure(label, f).Width, FileTitleWidth - 20);
                        Draw.Ellipsis(g, label, new(TitleX + 18, ly - 9, lw + 4, 18), f, Ink.A(ink, hover ? .9 : .5));
                        AddHit(new(TitleX - 4, ly - 10, lw + 26, 20), "fileLink", item.TaskId);
                    }
                    break;
                }
                case "header":
                case "doneHeader":
                {
                    float hm = y + 23; bool doneList = item.Kind == "doneHeader";
                    var chev = new RectangleF(W - 8 - 30, hm - 15, 30, 30); var more = new RectangleF(chev.X - 33, chev.Y, 30, 30); var plus = new RectangleF(more.X - 33, chev.Y, 30, 30);
                    if (doneList)
                    {
                        int count = host.Store.DoneTasks().Count;
                        float nameW = Draw.Text(g, L.T("doneList"), 50, hm, Fonts.Text(15), ink, heavy: true);
                        Draw.Text(g, count.ToString(), 50 + nameW + 10, hm, Fonts.Text(12), Ink.A(ink, .55));
                        Draw.Circle(g, new(14, hm - 13, 26, 26), Ink.A(ink, .10));
                        Draw.Icon(g, "check", new(14, hm - 13, 26, 26), 13, Ink.A(ink, .7), 2.4f);
                        AddHit(new(0, y, more.X - 4, SecHeadH), "doneHeader");
                        bool collapsed = host.Store.DoneCollapsed;
                        if (!collapsed && count > 0)
                        {
                            var f = Fonts.Text(13); var size = Draw.Measure(L.T("clearDone"), f);
                            var clear = new RectangleF(chev.X - 8 - size.Width - 20, hm - 14, size.Width + 20, 28);
                            if (Hovered("clearDone", null)) Draw.Round(g, clear, 14, Ink.A(ink, .09));
                            Draw.Text(g, L.T("clearDone"), clear.X + 10, hm, f, Ink.A(ink, .7));
                            AddHit(clear, "clearDone");
                        }
                        RoundButton(g, collapsed ? "chevRight" : "chevDown", chev, "doneToggle", null, ink, .09);
                    }
                    else if (section != null)
                    {
                        var num = new RectangleF(14, hm - 13, 26, 26);
                        Draw.Circle(g, num, Ink.A(ink, .12));
                        string numText = (item.Band + 1).ToString(); var numFont = Fonts.Text(12);
                        Draw.Text(g, numText, num.X + num.Width / 2 - Draw.Measure(numText, numFont).Width / 2, hm, numFont, ink, heavy: true);
                        if (editKind == "renameSection" && editTarget == item.SectionId)
                        {
                            FormRow(g, new(50, y + 3, W - 8 - 50, SecHeadH - 6), 50, null, ink, fill); editorPlaced = true;
                        }
                        else
                        {
                            var all = host.Store.InSection(section.Id); int done = all.Count(x => x.Done);
                            var nameFont = Fonts.Text(15);
                            float nameW = Math.Min(Draw.Measure(section.Title, nameFont).Width, plus.X - 12 - 50 - 40);
                            if (nameW < Draw.Measure(section.Title, nameFont).Width) Draw.Ellipsis(g, section.Title, new(50, hm - 12, nameW + 4, 24), nameFont, ink);
                            else Draw.Text(g, section.Title, 50, hm, nameFont, ink, heavy: true);
                            Draw.Text(g, $"{done}/{all.Count}", 50 + nameW + 10, hm, Fonts.Text(12), Ink.A(ink, .55), heavy: true);
                            AddHit(new(0, y, plus.X - 4, SecHeadH), "sectionHead", section.Id);
                            RoundButton(g, "plus", plus, "plus", section.Id, ink, .09);
                            RoundButton(g, "more", more, "sectionMore", section.Id, ink, .09);
                            RoundButton(g, section.Collapsed ? "chevRight" : "chevDown", chev, "collapse", section.Id, ink, .09);
                        }
                    }
                    break;
                }
                case "taskForm":
                    Draw.Rect(g, new(52, y, W - 62, 1), Ink.A(ink, .14));
                    FormRow(g, new(52, y, W - 62, item.H), TitleX, editKind == "link" ? "link" : editKind is "task" or "fileTask" ? "dash" : "circle", ink, fill);
                    editorPlaced = true; break;
                case "empty":
                    Draw.Rect(g, new(52, y, W - 62, 1), Ink.A(ink, .14));
                    Draw.Text(g, L.T("empty"), 54, y + RowH / 2, Fonts.Text(14), Ink.A(ink, .55)); break;
                case "row":
                case "doneRow":
                    if (task == null) break;
                    DrawTaskRow(g, item, task, y, ink, fill, section); break;
            }
            if (fade != null) g.EndContainer(fade);
        }

        if (dragging && dragSection != null && dropGap >= 0)
        {
            var order = blocks.Where(b => b.SectionId != null).ToList();
            float ly = dropGap < order.Count ? order[dropGap].Top : order.LastOrDefault()?.Bottom ?? 0;
            Draw.Round(g, new(12, top + ly - 1.5f, W - 24, 3), 1.5f, t.Ink);
        }
        if (dragging && dragTask != null && drop != null && !float.IsNaN(drop.LineY))
        {
            int index = host.Store.Sections.ToList().FindIndex(s => s.Id == drop.SectionId);
            Draw.Round(g, new(48, top + drop.LineY - 1.5f, W - 58, 3), 1.5f, index < 0 ? (drop.SectionId == "file" ? t.PopoverInk : t.Ink) : t.BandInk(index));
        }
        if (editor != null) editor.Visible = editorPlaced;
        foreach (var hit in hits)
            if (hit.Action is not ("toggle" or "reset" or "phase" or "settings" or "close"))
                hit.Rect = RectangleF.Intersect(hit.Rect, new RectangleF(0, HeadH, W, H - HeadH));
    }

    void DrawTaskRow(Graphics g, Item item, TaskEntry task, float y, Color ink, Color fill, TaskSection? section)
    {
        float W = Width0; bool doneRow = item.Kind == "doneRow"; string tid = task.Id;
        bool selected = !doneRow && host.Store.ActiveTaskId == tid;
        float firstMid = y + 20;
        if (Hovered("row", tid) || Hovered("check", tid) || Hovered("more", tid) || Hovered("link", tid)) Draw.Rect(g, new(52, y, W - 62, item.H), Ink.A(ink, .05));
        Draw.Rect(g, new(52, y, W - 62, 1), Ink.A(ink, .14));
        // The row goes first so the circle, "•••" and the link, added later, win the click.
        AddHit(new(0, y, W - 10 - 30, item.H), doneRow ? "doneRow" : "row", tid);
        if (selected) { var go = new RectangleF(14, firstMid - 12, 24, 24); Draw.Circle(g, go, ink); Draw.Icon(g, "arrow", go, 14, fill, 2.6f); }
        var check = new RectangleF(54, firstMid - 10, 20, 20);
        if (doneRow) { Draw.Circle(g, check, Ink.A(ink, .8)); Draw.Icon(g, "check", check, 12, fill, 3); }
        else Draw.Ring(g, RectangleF.Inflate(check, -1, -1), ink, 2);
        AddHit(RectangleF.Inflate(check, 6, 8), "check", tid);
        var moreRect = new RectangleF(W - 10 - 30, firstMid - 15, 30, 30);
        if (Hovered("more", tid)) Draw.Circle(g, moreRect, Ink.A(ink, .12));
        Draw.Icon(g, "more", moreRect, 16, Ink.A(ink, .7), 2);
        AddHit(moreRect, "more", tid);
        float right = moreRect.X - 8;
        if (doneRow) Draw.Ellipsis(g, host.Store.Section(task.SectionId)?.Title ?? "", new(right - 82, firstMid - 9, 82, 18), Fonts.Text(12), Ink.A(ink, .5));
        else if (host.Scope == "task")
        {
            double remaining = selected && host.ActiveFileTitle == null && host.Timer.State.Phase == "work" ? host.Timer.RemainingAt(ShiroContext.Now) : task.Remaining;
            if (remaining < 0) remaining = host.Timer.State.WorkSeconds;
            Draw.Text(g, TimeText(remaining), right, firstMid, Fonts.Display(12, 400), Ink.A(ink, .6), alignRight: true);
        }
        float width = TitleWidth(doneRow);
        Draw.Wrapped(g, task.Title, new(TitleX, y + 10, width, item.TitleH + 2), TitleFont, doneRow ? Ink.A(ink, .5) : ink, selected, doneRow);
        if (!string.IsNullOrEmpty(task.Link))
        {
            float ly = y + 10 + item.TitleH + 9; bool hover = Hovered("link", tid); double rest = doneRow ? .4 : .55;
            Draw.Icon(g, "link", new(TitleX - 1, ly - 7, 14, 14), 13, Ink.A(ink, hover ? .9 : rest), 2);
            var f = Fonts.Text(12); string label = LinkLabel(task.Link); float lw = Math.Min(Draw.Measure(label, f).Width, width - 20);
            Draw.Ellipsis(g, label, new(TitleX + 18, ly - 9, lw + 4, 18), f, Ink.A(ink, hover ? .9 : rest));
            if (hover) Draw.Rect(g, new(TitleX + 18, ly + 8, lw, 1), Ink.A(ink, .5));
            AddHit(new(TitleX - 4, ly - 10, lw + 26, 20), "link", tid);
        }
    }

    // ---------- Editing ----------
    void PositionEditor()
    {
        if (editor == null) return;
        var r = ToView(editorRect);
        editor.Bounds = Rectangle.Round(r);
        editor.Font = Fonts.Text(15 * K);
    }
    internal void StartEdit(string kind, string? target, string text)
    {
        if (editKind != null) CommitEdit(false);
        if (editKind != null) EndEdit();   // saving a new section opens its first task row; this request wins
        editKind = kind; editTarget = target;
        editor = new TextBox { BorderStyle = BorderStyle.None, Multiline = true, WordWrap = true, AcceptsReturn = false, Text = text ?? "" };
        editor.PlaceholderText = L.T(kind is "section" or "renameSection" ? "sectionName" : kind == "renameTask" ? "taskName" : kind == "link" ? "linkPlaceholder" : "newTask");
        editor.KeyDown += EditorKeyDown;
        editor.TextChanged += (_, _) => { host.ContentChanged(); Invalidate(); };
        editor.Leave += (_, _) => { if (!finishingEdit && editKind != null) CommitEdit(false); };
        Controls.Add(editor);
        host.ContentChanged();
        BuildLayout(); Invalidate(); Update();
        ScrollEditorIntoView();
        editor.Focus(); editor.SelectionStart = editor.Text.Length;
    }
    void ScrollEditorIntoView()
    {
        float topY = editorRect.Y - 12, bottom = editorRect.Bottom + 16, H = Logical.Height;
        if (bottom > H) scrollY += bottom - H; else if (topY < HeadH) scrollY -= HeadH - topY;
        ClampScroll(); Invalidate(); Update();
    }
    void EditorKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter) { e.SuppressKeyPress = true; CommitEdit(editKind is "task" or "fileTask"); }
        else if (e.KeyCode == Keys.Escape) { e.SuppressKeyPress = true; EndEdit(); }
        else if (e.Control && e.KeyCode == Keys.A) { e.SuppressKeyPress = true; editor?.SelectAll(); }
    }
    void EndEdit()
    {
        if (editor == null) { editKind = editTarget = null; return; }
        finishingEdit = true;
        var old = editor; editor = null; editKind = editTarget = null;
        Controls.Remove(old); old.Dispose();
        finishingEdit = false;
        ClampScroll(); Invalidate(); host.ContentChanged();
        Focus();
    }
    // Saves what was typed. A link may be saved empty (that removes it); empty titles are dropped.
    void CommitEdit(bool continueAdding)
    {
        if (editKind == null) return;
        string text = (editor?.Text ?? "").Replace("\r", " ").Replace("\n", " ").Trim();
        string kind = editKind; string? target = editTarget;
        EndEdit();
        if (kind == "link") { host.SetLink(target!, text); return; }
        if (text.Length == 0) return;
        switch (kind)
        {
            case "task": host.AddTask(text, target!); if (continueAdding) BeginAddingTask(target!); break;
            case "fileTask": host.AddTaskToFile(text); if (continueAdding) StartEdit("fileTask", "file", ""); break;
            case "section": { string? created = host.AddSection(text); if (created != null) BeginAddingTask(created); break; }
            case "renameTask": host.RenameTask(target!, text); break;
            case "renameSection": host.RenameSection(target!, text); break;
        }
    }
    internal void BeginAddingTask(string sectionId)
    {
        if (editKind != null) CommitEdit(false);
        host.ExpandSection(sectionId);
        StartEdit("task", sectionId, "");
    }

    // ---------- Mouse ----------
    Hit? HitAt(PointF p) { for (int i = hits.Count - 1; i >= 0; i--) if (hits[i].Rect.Contains(p)) return hits[i]; return null; }
    internal string? ActionAt(PointF logical) => HitAt(logical)?.Action;
    protected override void OnMouseMove(MouseEventArgs e)
    {
        base.OnMouseMove(e);
        var p = LogicalPoint(e.Location);
        if (e.Button == MouseButtons.Left && (dragSection != null || dragTask != null)) { Drag(p); return; }
        var hit = HitAt(p);
        string? key = hit != null ? Key(hit.Action, hit.Ident) : null;
        if (key != hoverKey) { hoverKey = key; Invalidate(); }
        Cursor = hit != null && (hit.Action is "link" or "fileLink") ? Cursors.Hand : Cursors.Default;
    }
    protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); if (hoverKey != null) { hoverKey = null; Invalidate(); } }
    protected override void OnMouseWheel(MouseEventArgs e)
    {
        base.OnMouseWheel(e);
        float before = scrollY; scrollY -= e.Delta / 120f * 40; ClampScroll();
        if (scrollY != before) Invalidate();
    }
    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button == MouseButtons.Right) return;
        var p = LogicalPoint(e.Location); var hit = HitAt(p);
        pressAction = hit?.Action; pressIdent = hit?.Ident; pressPoint = p;
        dragging = false; drop = null; dropGap = -1;
        dragSection = hit?.Action == "sectionHead" ? hit.Ident : hit?.Action == "fileHeader" ? "file" : null;
        dragTask = hit != null && hit.Action is "row" or "doneRow" or "fileRow" ? hit.Ident : null;
        if (hit == null && editKind != null) CommitEdit(false);
        if (hit == null && p.Y < BarH) { ReleaseCapture(); SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero); }   // drag the window by its title bar
    }
    void Drag(PointF p)
    {
        if (!dragging && Math.Abs(p.X - pressPoint.X) + Math.Abs(p.Y - pressPoint.Y) > 4)
        {
            if (editKind != null) CommitEdit(false);
            dragging = true; Cursor = Cursors.SizeAll; host.ContentChanged();
        }
        if (!dragging) return;
        if (p.Y > Logical.Height - 24) scrollY += 8; else if (p.Y < HeadH + 24) scrollY -= 8;
        ClampScroll();
        float listY = p.Y - HeadH + scrollY;
        BuildLayout();
        if (dragSection != null)
        {
            var order = blocks.Where(b => b.SectionId != null).ToList(); int gap = 0;
            for (int i = 0; i < order.Count; i++) if (listY > (order[i].Top + order[i].Bottom) / 2) gap = i + 1;
            dropGap = gap;
        }
        else drop = DropFor(listY);
        Invalidate();
    }
    Drop? DropFor(float listY)
    {
        bool fromFile = dragTask?.StartsWith("file:") == true;
        foreach (var block in blocks)
        {
            if (listY < block.Top || listY >= block.Bottom) continue;
            // Inside the file block a file task changes places (Shiro's own order; the file is not touched).
            if (block.SectionId == "file" && fromFile && !block.Collapsed) return FileDrop(listY);
            if (block.SectionId == "file" || (fromFile && block.SectionId == null)) return null;
            if (block.SectionId == null || block.Collapsed) return new Drop { SectionId = block.SectionId };
        }
        if (!fromFile && blocks.Count > 0 && listY >= blocks[^1].Bottom && blocks[^1].SectionId == null) return new Drop();
        Drop? best = null; float bestDistance = float.MaxValue;
        foreach (var block in blocks)
        {
            if (block.SectionId == null || block.Collapsed || block.SectionId == "file") continue;
            var gaps = new List<(float y, string? before)>(); float endY = block.Top + SecHeadH;
            foreach (var item in items)
            {
                if (item.SectionId != block.SectionId || item.Band < 0) continue;
                if (item.Kind == "row") { gaps.Add((item.Y, item.TaskId)); endY = item.Y + item.H; }
                else if (item.Kind is "empty" or "taskForm") endY = Math.Max(endY, item.Y + item.H);
            }
            gaps.Add((endY, null));
            foreach (var (gy, before) in gaps)
                if (Math.Abs(gy - listY) < bestDistance) { bestDistance = Math.Abs(gy - listY); best = new Drop { SectionId = block.SectionId, LineY = gy, BeforeId = before }; }
        }
        return best;
    }
    Drop? FileDrop(float listY)
    {
        var rows = items.Where(i => i.Kind == "fileRow").ToList();
        Drop? best = null; float bestDistance = float.MaxValue;
        void Consider(float gy, int before, string section)
        {
            if (Math.Abs(gy - listY) >= bestDistance) return;
            bestDistance = Math.Abs(gy - listY);
            best = new Drop { SectionId = "file", LineY = gy, BeforeId = (before >= 0 ? "file:" + before : "end") + "|" + section };
        }
        for (int i = 0; i < rows.Count; i++)
        {
            int index = int.Parse(rows[i].TaskId![5..]); string section = host.FileTasks[index].Section;
            Consider(rows[i].Y, index, section);
            bool last = i + 1 == rows.Count;
            if (last || host.FileTasks[int.Parse(rows[i + 1].TaskId![5..])].Section != section) Consider(rows[i].Y + rows[i].H, -1, section);
        }
        return best;
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        var p = LogicalPoint(e.Location);
        if (dragging)
        {
            Cursor = Cursors.Default;
            string? section = dragSection, taskId = dragTask; var d = drop; int gap = dropGap;
            dragging = false; dragSection = dragTask = null; drop = null; dropGap = -1;
            if (section != null)
            {
                BuildLayout();
                var keys = blocks.Where(b => b.SectionId != null).Select(b => b.SectionId!).ToList();
                int old = keys.IndexOf(section), target = gap > old ? gap - 1 : gap;
                if (old >= 0 && gap >= 0 && target != old)
                {
                    keys.RemoveAt(old); keys.Insert(Math.Min(target, keys.Count), section);
                    host.ReorderBlocks(keys);
                }
            }
            else if (taskId != null && taskId.StartsWith("file:"))
            {
                int index = int.Parse(taskId[5..]);
                if (d?.SectionId == "file")
                {
                    var parts = d.BeforeId!.Split('|', 2);
                    int before = parts[0].StartsWith("file:") ? int.Parse(parts[0][5..]) : -1;
                    if (before != index) host.MoveFileTask(index, before, parts.Length > 1 ? parts[1] : "");
                }
                else if (d?.SectionId != null) host.ImportFileTask(index, d.SectionId, d.BeforeId);
            }
            else if (taskId != null && d != null)
            {
                bool done = host.Store.Task(taskId)?.Done == true;
                if (d.SectionId == null) { if (!done) host.ToggleTask(taskId); }
                else host.MoveTask(taskId, d.SectionId, d.BeforeId);
            }
            host.ContentChanged(); Invalidate();
            return;
        }
        dragSection = dragTask = null;
        if (e.Button == MouseButtons.Right) return;
        var hit = HitAt(p);
        if (hit == null || hit.Action != pressAction || hit.Ident != pressIdent) return;
        Perform(hit.Action, hit.Ident, hit.Rect, e.Clicks);
    }
    protected override void OnMouseDoubleClick(MouseEventArgs e)
    {
        base.OnMouseDoubleClick(e);
        // Double click on a task or a section name edits it in place.
        var hit = HitAt(LogicalPoint(e.Location));
        if (hit?.Action == "row") StartEdit("renameTask", hit.Ident, host.Store.Task(hit.Ident)?.Title ?? "");
        else if (hit?.Action == "sectionHead") StartEdit("renameSection", hit.Ident, host.Store.Section(hit.Ident)?.Title ?? "");
    }
    void Perform(string action, string? ident, RectangleF rect, int clicks)
    {
        if (action == "formOK") { CommitEdit(false); return; }
        if (action == "formCancel") { EndEdit(); return; }
        // Any other click keeps what was typed and then does its own thing (for example "+" opens the next row).
        if (editKind != null && action != "sectionHead") CommitEdit(false);
        int FileIndex() => int.Parse(ident![5..]);
        switch (action)
        {
            case "toggle": host.ToggleTimer(); break;
            case "reset": host.ResetTimer(); break;
            case "phase": host.SwitchPhase(ident!); break;
            case "settings": host.ShowSettings(); break;
            case "close": host.ClosePanel(); break;
            case "addSection": StartEdit("section", null, ""); break;
            case "plus": BeginAddingTask(ident!); break;
            case "collapse": host.ToggleSection(ident!); break;
            case "doneHeader": case "doneToggle": host.ToggleDoneList(); break;
            case "clearDone":
                int count = host.Store.DoneTasks().Count;
                if (count > 0 && MessageBox.Show(this, L.ClearDoneQuestion(count), "Широ", MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) == DialogResult.Yes) host.ClearDone();
                break;
            case "row": if (clicks < 2) host.SelectTask(ident!); break;
            case "check": host.ToggleTask(ident!); break;
            case "link": OpenLink(host.Store.Task(ident)?.Link); break;
            case "fileHeader": case "fileToggle": host.ToggleFileBlock(); break;
            case "fileAdd": if (host.FileCollapsed) host.ToggleFileBlock(); StartEdit("fileTask", "file", ""); break;
            case "fileRow": host.SelectFileTask(FileIndex()); break;
            case "fileCheck": host.ToggleFileTask(FileIndex()); break;
            case "import": host.ImportFileTaskMenu(FileIndex(), PointToScreen(Point.Round(new PointF(ToView(rect).Left, ToView(rect).Bottom)))); break;
            case "fileLink": OpenLink(host.FileTasks[FileIndex()].Link); break;
            case "more": case "sectionMore": ShowMenu(action, ident!, rect); break;
        }
    }
    internal static void OpenLink(string? link)
    {
        if (string.IsNullOrEmpty(link)) return;
        if (!link.Contains("://") && !link.StartsWith("mailto:", StringComparison.OrdinalIgnoreCase)) link = "https://" + link;
        try { Process.Start(new ProcessStartInfo(link) { UseShellExecute = true }); } catch (Exception error) when (error is System.ComponentModel.Win32Exception or InvalidOperationException) { }
    }
    void ShowMenu(string action, string ident, RectangleF rect)
    {
        var menu = new ContextMenuStrip();
        void AddItem(string key, Action run) => menu.Items.Add(L.T(key), null, (_, _) => run());
        if (action == "sectionMore")
        {
            AddItem("renameSection", () => StartEdit("renameSection", ident, host.Store.Section(ident)?.Title ?? ""));
            menu.Items.Add(new ToolStripSeparator());
            AddItem("deleteSection", () =>
            {
                int count = host.Store.InSection(ident).Count;
                if (count == 0 || MessageBox.Show(this, L.DeleteSectionQuestion(host.Store.Section(ident)?.Title ?? "", count), "Широ",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) == DialogResult.Yes) host.DeleteSection(ident);
            });
        }
        else if (host.Store.Task(ident)?.Done == true)
        {
            AddItem("backToActive", () => host.ToggleTask(ident));
            menu.Items.Add(new ToolStripSeparator());
            AddItem("deleteForever", () => host.DeleteTask(ident));
        }
        else
        {
            var task = host.Store.Task(ident); bool hasLink = !string.IsNullOrEmpty(task?.Link);
            AddItem("rename", () => StartEdit("renameTask", ident, task?.Title ?? ""));
            AddItem(hasLink ? "editLink" : "attachLink", () => StartEdit("link", ident, task?.Link ?? ""));
            if (hasLink) AddItem("removeLink", () => host.SetLink(ident, ""));
            menu.Items.Add(new ToolStripSeparator());
            AddItem("delete", () => host.DeleteTask(ident));
        }
        menu.Closed += (_, _) => BeginInvoke(() => menu.Dispose());
        var view = ToView(rect);
        menu.Show(this, Point.Round(new PointF(view.Left, view.Bottom + 4 * K)));
    }
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == Keys.Escape && editKind == null) { host.ClosePanel(); return true; }
        return base.ProcessCmdKey(ref msg, keyData);
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) { toastTimer.Dispose(); editor?.Dispose(); }
        base.Dispose(disposing);
    }
}
