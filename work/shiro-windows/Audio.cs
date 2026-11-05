using System.Runtime.InteropServices;
using System.Text;

namespace Shiro;

// Sounds through MCI: each file has its own volume and can play together with the looping keyboard sound.
// The embedded WAV files are copied to %LOCALAPPDATA%\Shiro\sounds the first time they are needed.
internal sealed class Audio : IDisposable
{
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)] static extern int mciSendString(string command, StringBuilder? result, int length, IntPtr callback);
    readonly string folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Shiro", "sounds");
    readonly HashSet<string> opened = new();
    readonly System.Windows.Forms.Timer fader = new() { Interval = 40 };
    double ambientLevel, ambientTarget;
    bool ambientPlaying;

    internal Audio() { fader.Tick += (_, _) => StepFade(); }

    static string Alias(string name) => "shiro_" + name.Replace('-', '_');
    bool Open(string name)
    {
        string alias = Alias(name);
        if (opened.Contains(alias)) return true;
        string path = Path.Combine(folder, name + ".wav");
        try
        {
            if (!File.Exists(path))
            {
                Directory.CreateDirectory(folder);
                using var source = Assets.Open(name + ".wav");
                using var target = File.Create(path);
                source.CopyTo(target);
            }
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { return false; }
        // "mpegvideo" (DirectShow) supports volume and looping; "waveaudio" supports neither.
        if (mciSendString($"open \"{path}\" type mpegvideo alias {alias}", null, 0, IntPtr.Zero) != 0) return false;
        opened.Add(alias); return true;
    }
    static void Volume(string alias, double volume) => mciSendString($"setaudio {alias} volume to {(int)Math.Round(Math.Clamp(volume, 0, 1) * 1000)}", null, 0, IntPtr.Zero);

    internal void Play(string name, double volume)
    {
        if (volume <= 0 || !Open(name)) return;
        string alias = Alias(name);
        Volume(alias, volume);
        mciSendString($"play {alias} from 0", null, 0, IntPtr.Zero);
    }

    // Keyboard sound: fades in while focus runs, fades out and pauses otherwise.
    internal void Ambient(bool on, double volume)
    {
        ambientTarget = on ? Math.Clamp(volume, 0, 1) : 0;
        if (on && !ambientPlaying)
        {
            if (!Open("ambient-keyboard")) return;
            mciSendString($"play {Alias("ambient-keyboard")} repeat", null, 0, IntPtr.Zero);
            ambientPlaying = true;
        }
        if (Math.Abs(ambientLevel - ambientTarget) > .005) fader.Start();
    }
    void StepFade()
    {
        double step = 0.06;
        ambientLevel = ambientLevel < ambientTarget ? Math.Min(ambientTarget, ambientLevel + step) : Math.Max(ambientTarget, ambientLevel - step);
        Volume(Alias("ambient-keyboard"), ambientLevel);
        if (Math.Abs(ambientLevel - ambientTarget) > .005) return;
        fader.Stop();
        if (ambientTarget <= 0 && ambientPlaying) { mciSendString($"pause {Alias("ambient-keyboard")}", null, 0, IntPtr.Zero); ambientPlaying = false; }
    }

    public void Dispose()
    {
        fader.Stop(); fader.Dispose();
        foreach (string alias in opened) mciSendString($"close {alias}", null, 0, IntPtr.Zero);
        opened.Clear();
    }
}
