using System.Text.Json;

namespace Shiro;

internal sealed record FrameClip(string File, int Frames, double Fps, bool Loop)
{
    internal double Duration => Frames / Fps;
    internal int IndexAt(double seconds)
    {
        double time = double.IsFinite(seconds) ? Math.Max(0, seconds) : 0;
        time = Loop ? time % Duration : Math.Min(time, Duration);
        return Math.Min(Frames - 1, (int)Math.Floor(time * Fps + 1e-8));
    }
}

internal sealed class AnimationFrames
{
    internal int Width { get; }
    internal int Height { get; }
    internal int Columns { get; }
    readonly Dictionary<int, FrameClip> clips = new();
    internal AnimationFrames(Stream stream)
    {
        using var doc = JsonDocument.Parse(stream);
        var root = doc.RootElement;
        Width = root.GetProperty("width").GetInt32(); Height = root.GetProperty("height").GetInt32();
        Columns = root.GetProperty("columns").GetInt32();
        if (root.GetProperty("version").GetInt32() != 1 || Width != 192 || Height != 208 || Columns < 1)
            throw new InvalidDataException("Invalid animation dimensions");
        foreach (var pair in root.GetProperty("clips").EnumerateObject())
        {
            var item = pair.Value;
            var clip = new FrameClip(item.GetProperty("file").GetString()!, item.GetProperty("frames").GetInt32(),
                item.GetProperty("fps").GetDouble(), item.GetProperty("loop").GetBoolean());
            if (string.IsNullOrEmpty(clip.File) || clip.File != Path.GetFileName(clip.File) || clip.Frames < 1 ||
                !double.IsFinite(clip.Fps) || clip.Fps <= 0 || clip.Fps > 120)
                throw new InvalidDataException("Invalid animation clip");
            clips.Add(int.Parse(pair.Name), clip);
        }
        foreach (int row in new[] { 0, 3, 5, 7, 8 })
            if (!clips.ContainsKey(row)) throw new InvalidDataException("Missing animation: " + row);
    }
    internal FrameClip Clip(int row) => clips.GetValueOrDefault(row, clips[0]);
}
