using System.Drawing.Drawing2D;
using System.Reflection;
using System.Text.Json;

namespace Shiro;

internal static class Assets
{
    internal static Stream Open(string name) => Assembly.GetExecutingAssembly()
        .GetManifestResourceStream("Shiro.Assets." + name) ?? throw new IOException("Missing asset: " + name);
    internal static Bitmap Bitmap(string name)
    {
        using var stream = Open(name);
        using var source = new Bitmap(stream);
        // Clone: GDI+ requires the originating stream to stay open otherwise.
        return new Bitmap(source);
    }
    internal static Icon Icon()
    {
        using var stream = Open("Shiro.ico");
        using var source = new Icon(stream);
        return (Icon)source.Clone();
    }
}

internal sealed class AnimationRig : IDisposable
{
    sealed class Pose
    {
        internal readonly Dictionary<string, Bitmap> Pieces = new();
        internal PointF TailPivot, ArmPivot;
    }
    readonly Dictionary<int, Pose> poses = new();
    internal AnimationRig()
    {
        using var stream = Assets.Open("rig.json");
        using var document = JsonDocument.Parse(stream);
        foreach (var item in document.RootElement.EnumerateObject())
        {
            var pose = new Pose();
            foreach (string name in new[] { "body", "tail", "arm", "feet", "bug", "joints" })
                if (item.Value.TryGetProperty(name, out var file)) pose.Pieces[name] = Assets.Bitmap(file.GetString()!);
            PointF Pivot(string name)
            {
                var array = item.Value.GetProperty(name);
                return new(array[0].GetSingle(), array[1].GetSingle());
            }
            pose.TailPivot = Pivot("tailPivot"); pose.ArmPivot = Pivot("armPivot");
            poses[int.Parse(item.Name)] = pose;
        }
    }
    static void Rotate(Graphics g, PointF pivot, double degrees)
    {
        g.TranslateTransform(pivot.X, pivot.Y);
        g.RotateTransform((float)degrees);
        g.TranslateTransform(-pivot.X, -pivot.Y);
    }
    internal void Draw(Graphics g, int row, double seconds, RectangleF bounds)
    {
        var pose = poses.GetValueOrDefault(row, poses[0]);
        var tracks = MotionTracks.At(row, seconds);
        var root = g.Save();
        g.TranslateTransform(bounds.X, bounds.Y);
        g.ScaleTransform(bounds.Width / 192, bounds.Height / 208);
        g.PixelOffsetMode = PixelOffsetMode.Half;
        void Piece(string name, bool moving = false)
        {
            if (!pose.Pieces.TryGetValue(name, out var bitmap)) return;
            g.InterpolationMode = moving ? InterpolationMode.Bilinear : InterpolationMode.NearestNeighbor;
            g.DrawImage(bitmap, new Rectangle(0, 0, 192, 208), 0, 0, 192, 208, GraphicsUnit.Pixel);
        }
        if (pose.Pieces.ContainsKey("bug"))
        {
            var saved = g.Save(); g.TranslateTransform((float)tracks.Bug, 0);
            Piece("bug", true); g.Restore(saved);
        }
        Piece("feet");
        var upper = g.Save();
        Rotate(g, new(97, 184), tracks.Lean);
        Piece("joints", row == 5);
        var tail = g.Save(); Rotate(g, pose.TailPivot, tracks.Tail); Piece("tail", true); g.Restore(tail);
        var arm = g.Save(); Rotate(g, pose.ArmPivot, tracks.Arm); Piece("arm", true); g.Restore(arm);
        Piece("body", row == 5);
        if (row == 8)
        {
            var saved = g.Save();
            using var lenses = new GraphicsPath();
            lenses.AddPolygon(new PointF[] { new(62, 85), new(115, 69), new(120, 81), new(72, 101) });
            g.SetClip(lenses, CombineMode.Intersect);
            float x = (float)(Math.Max(0, seconds) % 3.2 / 3.2 * 160);
            using var shine = new SolidBrush(Color.FromArgb(71, 255, 255, 255));
            g.FillPolygon(shine, new PointF[] { new(x, 65), new(x + 3, 65), new(x - 16, 109), new(x - 19, 109) });
            g.Restore(saved);
        }
        g.Restore(upper); g.Restore(root);
    }
    public void Dispose()
    {
        foreach (var pose in poses.Values) foreach (var piece in pose.Pieces.Values) piece.Dispose();
        poses.Clear();
    }
}
