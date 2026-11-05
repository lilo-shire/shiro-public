using System.Drawing.Drawing2D;
using System.Drawing.Text;

namespace Shiro;

internal interface ISettingsHost
{
    string ThemeId { get; }
    string Language { get; }
    string Scope { get; }
    string SoundPack { get; }
    double Volume { get; }
    bool Notify { get; }
    double UiScale { get; }
    bool Ambient { get; }
    double AmbientVolume { get; }
    double WorkMinutes { get; }
    double BreakMinutes { get; }
    string? LinkedFileName { get; }
    void ChangeTheme(string id); void ChangeLanguage(string language); void ChangeScope(string scope); void ChangeMinutes(double work, double rest);
    void ChangeVolume(double volume); void ChangeScale(double scale); void ChangeSoundPack(string pack); void ChangeNotify(bool on); void PreviewSound();
    void ChangeAmbient(bool on); void ChangeAmbientVolume(double volume); void ConnectFile(); void DisconnectFile();
}

// Eight colour circles, numbered as on the Mac.
internal sealed class ThemeGrid : Control
{
    internal string Selected = "pastel";
    internal event Action<string>? Chosen;
    internal ThemeGrid() { DoubleBuffered = true; Cursor = Cursors.Hand; }
    RectangleF Cell(int i) { float w = ClientSize.Width / 4f, h = ClientSize.Height / 2f; return new(i % 4 * w, i / 4 * h, w, h); }
    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.Clear(BackColor);
        float f = DeviceDpi / 96f;
        for (int i = 0; i < Theme.All.Length; i++)
        {
            var t = Theme.All[i]; var cell = Cell(i);
            float d = 36 * f; var sw = new RectangleF(cell.X + cell.Width / 2 - d / 2, cell.Y + 4 * f, d, d);
            var colors = new[] { t.HeadBackground, t.BandFill(0), t.BandFill(1), t.BandFill(2) };
            for (int q = 0; q < 4; q++) using (var b = new SolidBrush(colors[q])) g.FillPie(b, sw.X, sw.Y, sw.Width, sw.Height, -90 + q * 90, 90);
            using (var edge = new Pen(Color.FromArgb(30, 0, 0, 0), 1)) g.DrawEllipse(edge, sw);
            if (t.Id == Selected) using (var ring = new Pen(ForeColor, 2 * f)) g.DrawEllipse(ring, RectangleF.Inflate(sw, 4 * f, 4 * f));
            var font = Fonts.Display(12 * f, 400); var size = Draw.Measure(t.Number, font);
            Draw.Text(g, t.Number, cell.X + cell.Width / 2 - size.Width / 2, sw.Bottom + 10 * f, font, ForeColor);
        }
    }
    protected override void OnMouseUp(MouseEventArgs e)
    {
        base.OnMouseUp(e);
        for (int i = 0; i < Theme.All.Length; i++) if (Cell(i).Contains(e.Location)) { Selected = Theme.All[i].Id; Invalidate(); Chosen?.Invoke(Selected); }
    }
}

internal sealed class SettingsForm : Form
{
    readonly ISettingsHost host;
    readonly Label title = new(), themeLabel = new(), timerLabel = new(), help = new(), workLabel = new(), breakLabel = new(), volumeLabel = new(), volumeValue = new(),
        soundLabel = new(), ambientLabel = new(), sizeLabel = new(), languageLabel = new(), fileLabel = new(), fileValue = new();
    readonly ThemeGrid grid = new();
    readonly ComboBox scope = new() { DropDownStyle = ComboBoxStyle.DropDownList }, pack = new() { DropDownStyle = ComboBoxStyle.DropDownList };
    readonly NumericUpDown work = new() { Minimum = 1, Maximum = 180 }, rest = new() { Minimum = 1, Maximum = 60 };
    readonly TrackBar volume = new() { Minimum = 0, Maximum = 100, TickStyle = TickStyle.None }, ambientVolume = new() { Minimum = 0, Maximum = 100, TickStyle = TickStyle.None };
    readonly Button listen = new() { Text = "▶" }, fileButton = new();
    readonly CheckBox notify = new(), ambient = new();
    readonly RadioButton[] sizes = { new() { Text = "S" }, new() { Text = "M" }, new() { Text = "L" } };
    readonly RadioButton ru = new() { Text = "Рус" }, en = new() { Text = "Eng" };
    bool filling;
    internal DateTime HiddenAt;   // a click on the gear hides the window first; it must not reopen it right away

    internal SettingsForm(ISettingsHost host)
    {
        this.host = host;
        Text = "Широ"; FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; StartPosition = FormStartPosition.Manual;
        AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96, 96); ClientSize = new(300, 700);
        BackColor = Color.White; ForeColor = Color.FromArgb(29, 28, 33);
        Font = new Font("Segoe UI", 9.75f);
        const int P = 16, W = 300, inner = W - 2 * P;
        int half = (inner - 10) / 2;
        void Put(Control c, int x, int y, int w, int h) { c.SetBounds(x, y, w, h); Controls.Add(c); }
        void Caption(Label l, int x, int y, int w) { l.ForeColor = Color.FromArgb(110, 110, 118); l.AutoSize = false; Put(l, x, y, w, 20); }
        title.Font = new Font("Segoe UI Semibold", 12f); Put(title, P, 12, inner, 26);
        Caption(themeLabel, P, 44, inner);
        Put(grid, P - 4, 66, inner + 8, 124);
        Caption(timerLabel, P, 200, inner); Put(scope, P, 222, inner, 28);
        help.ForeColor = Color.FromArgb(110, 110, 118); help.Font = new Font("Segoe UI", 8.75f); Put(help, P, 254, inner, 36);
        Caption(workLabel, P, 294, half); Caption(breakLabel, P + half + 10, 294, half);
        Put(work, P, 316, half, 28); Put(rest, P + half + 10, 316, half, 28);
        Caption(volumeLabel, P, 354, inner - 50); volumeValue.TextAlign = ContentAlignment.TopRight; Caption(volumeValue, W - P - 50, 354, 50);
        Put(volume, P - 6, 374, inner + 12, 30);
        Caption(soundLabel, P, 406, inner); Put(pack, P, 428, inner - 40, 28); Put(listen, W - P - 34, 427, 34, 28);
        Put(ambient, P, 466, inner, 24);
        Caption(ambientLabel, P + 20, 494, 110); Put(ambientVolume, P + 126, 490, inner - 126, 30);
        Put(notify, P, 524, inner, 24);
        Caption(sizeLabel, P, 560, 150);
        // Separate containers: radio buttons sharing a parent would form one group.
        var sizeGroup = new Panel(); Put(sizeGroup, W - P - 120, 554, 120, 28);
        for (int i = 0; i < 3; i++) { sizes[i].Appearance = Appearance.Button; sizes[i].TextAlign = ContentAlignment.MiddleCenter; sizes[i].SetBounds(i * 40, 0, 40, 28); sizeGroup.Controls.Add(sizes[i]); }
        Caption(languageLabel, P, 598, 150);
        var languageGroup = new Panel(); Put(languageGroup, W - P - 120, 592, 120, 28);
        foreach (var (b, i) in new[] { (ru, 0), (en, 1) }) { b.Appearance = Appearance.Button; b.TextAlign = ContentAlignment.MiddleCenter; b.SetBounds(i * 60, 0, 60, 28); languageGroup.Controls.Add(b); }
        var line = new Label { BorderStyle = BorderStyle.Fixed3D, AutoSize = false }; Put(line, P, 632, inner, 2);
        Caption(fileLabel, P, 642, inner);
        fileValue.AutoEllipsis = true; fileValue.AutoSize = false; fileValue.Font = new Font("Segoe UI Semibold", 9.75f); Put(fileValue, P, 668, inner - 156, 22);
        Put(fileButton, W - P - 150, 663, 150, 30);
        ClientSize = new(W, 706);

        grid.Chosen += id => { host.ChangeTheme(id); Fill(); };
        scope.SelectedIndexChanged += (_, _) => { if (!filling) { host.ChangeScope(scope.SelectedIndex == 1 ? "task" : "global"); Fill(); } };
        work.ValueChanged += (_, _) => { if (!filling) host.ChangeMinutes((double)work.Value, (double)rest.Value); };
        rest.ValueChanged += (_, _) => { if (!filling) host.ChangeMinutes((double)work.Value, (double)rest.Value); };
        volume.Scroll += (_, _) => { host.ChangeVolume(volume.Value / 100d); volumeValue.Text = volume.Value + "%"; };
        volume.MouseUp += (_, _) => host.PreviewSound();
        pack.SelectedIndexChanged += (_, _) => { if (!filling) { host.ChangeSoundPack(new[] { "glass", "wood", "air" }[Math.Max(0, pack.SelectedIndex)]); host.PreviewSound(); } };
        listen.Click += (_, _) => host.PreviewSound();
        ambient.CheckedChanged += (_, _) => { if (!filling) { host.ChangeAmbient(ambient.Checked); Fill(); } };
        ambientVolume.Scroll += (_, _) => host.ChangeAmbientVolume(ambientVolume.Value / 100d);
        notify.CheckedChanged += (_, _) => { if (!filling) host.ChangeNotify(notify.Checked); };
        double[] steps = { .72, .86, 1.0 };
        for (int i = 0; i < 3; i++) { int step = i; sizes[i].CheckedChanged += (_, _) => { if (!filling && sizes[step].Checked) host.ChangeScale(steps[step]); }; }
        ru.CheckedChanged += (_, _) => { if (!filling && ru.Checked) { host.ChangeLanguage("ru"); Fill(); } };
        en.CheckedChanged += (_, _) => { if (!filling && en.Checked) { host.ChangeLanguage("en"); Fill(); } };
        fileButton.Click += (_, _) => { if (host.LinkedFileName != null) { host.DisconnectFile(); Fill(); } else { Hide(); host.ConnectFile(); } };
        Deactivate += (_, _) => { if (Visible) { Hide(); HiddenAt = DateTime.UtcNow; } };
        Fill();
    }
    protected override CreateParams CreateParams { get { var p = base.CreateParams; p.ClassStyle |= 0x20000; p.ExStyle |= 0x80; return p; } }
    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        using var pen = new Pen(Color.FromArgb(40, 0, 0, 0)); e.Graphics.DrawRectangle(pen, 0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
    }
    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == Keys.Escape) { Hide(); return true; }
        return base.ProcessCmdKey(ref msg, keyData);
    }

    internal void Fill()
    {
        filling = true;
        title.Text = L.T("settings"); themeLabel.Text = L.T("theme"); grid.Selected = host.ThemeId; grid.Invalidate();
        timerLabel.Text = L.T("timer");
        scope.Items.Clear(); scope.Items.AddRange(new object[] { L.T("scopeGlobal"), L.T("scopeTask") }); scope.SelectedIndex = host.Scope == "task" ? 1 : 0;
        help.Text = L.T(host.Scope == "task" ? "helpTask" : "helpGlobal");
        workLabel.Text = L.T("workMin"); breakLabel.Text = L.T("breakMin");
        work.Value = (decimal)Math.Clamp(Math.Round(host.WorkMinutes), 1, 180); rest.Value = (decimal)Math.Clamp(Math.Round(host.BreakMinutes), 1, 60);
        volumeLabel.Text = L.T("volume"); volume.Value = (int)Math.Round(host.Volume * 100); volumeValue.Text = volume.Value + "%";
        soundLabel.Text = L.T("sound");
        pack.Items.Clear(); pack.Items.AddRange(new object[] { L.T("glass"), L.T("wood"), L.T("air") });
        pack.SelectedIndex = Math.Max(0, Array.IndexOf(new[] { "glass", "wood", "air" }, host.SoundPack));
        ambient.Text = L.T("ambient"); ambient.Checked = host.Ambient;
        ambientLabel.Text = L.T("ambientVolume"); ambientVolume.Value = (int)Math.Round(host.AmbientVolume * 100); ambientVolume.Enabled = host.Ambient;
        notify.Text = L.T("notify"); notify.Checked = host.Notify;
        sizeLabel.Text = L.T("windowSize");
        double[] steps = { .72, .86, 1.0 };
        int nearest = 0; for (int i = 1; i < 3; i++) if (Math.Abs(steps[i] - host.UiScale) < Math.Abs(steps[nearest] - host.UiScale)) nearest = i;
        for (int i = 0; i < 3; i++) sizes[i].Checked = i == nearest;
        languageLabel.Text = L.T("language"); ru.Checked = host.Language != "en"; en.Checked = host.Language == "en";
        fileLabel.Text = L.T("fileTitle"); fileValue.Text = host.LinkedFileName ?? L.T("fileNone");
        fileValue.ForeColor = host.LinkedFileName != null ? ForeColor : Color.FromArgb(110, 110, 118);
        fileButton.Text = L.T(host.LinkedFileName != null ? "disconnectFile" : "connectFile");
        filling = false;
    }
}
