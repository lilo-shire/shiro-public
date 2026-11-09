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
    internal static AnimationFrames Timing { get; } = LoadTiming();
    readonly AnimationFrames frames = Timing;
    static AnimationFrames LoadTiming()
    {
        using var stream = Assets.Open("animations.manifest.json");
        return new AnimationFrames(stream);
    }
    readonly Dictionary<string, Bitmap> atlases = new();
    readonly Queue<string> loaded = new();
    internal void Draw(Graphics g, int row, double seconds, RectangleF bounds)
    {
        var clip = frames.Clip(row);
        if (!atlases.TryGetValue(clip.File, out var atlas))
        {
            if (loaded.Count >= 2)
            {
                string old = loaded.Dequeue(); atlases[old].Dispose(); atlases.Remove(old);
            }
            atlas = Assets.Bitmap("animations." + clip.File);
            atlases.Add(clip.File, atlas); loaded.Enqueue(clip.File);
        }
        int index = clip.IndexAt(seconds);
        var source = new Rectangle(index % frames.Columns * frames.Width,
            index / frames.Columns * frames.Height, frames.Width, frames.Height);
        var saved = g.Save();
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        // Each tile has a transparent border, preventing neighboring-frame bleed.
        using var attributes = new System.Drawing.Imaging.ImageAttributes();
        attributes.SetWrapMode(WrapMode.TileFlipXY);
        g.DrawImage(atlas, Rectangle.Round(bounds), source.X, source.Y, source.Width, source.Height, GraphicsUnit.Pixel, attributes);
        g.Restore(saved);
    }
    public void Dispose()
    {
        foreach (var atlas in atlases.Values) atlas.Dispose();
        atlases.Clear(); loaded.Clear();
    }
}
