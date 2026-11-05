using System.Globalization;
using System.Text.Json;

namespace Shiro;

// Everything Shiro remembers between launches, stored as JSON in %LOCALAPPDATA%\Shiro\state.json.
public sealed class AppState
{
    public int Version { get; set; } = 6;
    public TimerState Timer { get; set; } = new();
    public TaskState? Checklist { get; set; }
    public string Theme { get; set; } = "pastel";
    public string? Language { get; set; }
    public string Scope { get; set; } = "global";
    public string SoundPack { get; set; } = "glass";
    public double Volume { get; set; } = .8;
    public bool Notify { get; set; } = true;
    public double UiScale { get; set; } = .72;
    public bool Ambient { get; set; }
    public double AmbientVolume { get; set; } = .35;
    public double GlobalWorkRemaining { get; set; } = -1;
    public int? X { get; set; }
    public int? Y { get; set; }
    public string? LinkedFile { get; set; }
    public bool LinkedFileCollapsed { get; set; }
    public int LinkedFileIndex { get; set; } = int.MaxValue;
    public string? ActiveFileTask { get; set; }
    public Dictionary<string, double> FileTaskRemaining { get; set; } = new();
    public List<string> FileTaskOrder { get; set; } = new();
    public Dictionary<string, string> FileTaskGroups { get; set; } = new();

    public static string SystemLanguage() => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "ru" ? "ru" : "en";

    // Reads a 0.6 file, or converts the flat 0.5 file (timer, sound and checklist in one object).
    public static AppState Load(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new();
        try
        {
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;
            if (root.TryGetProperty("Version", out var version) && version.ValueKind == JsonValueKind.Number && version.GetInt32() >= 6)
                return JsonSerializer.Deserialize<AppState>(json) ?? new();
            var legacy = JsonSerializer.Deserialize<LegacyState>(json) ?? new();
            return new AppState
            {
                Timer = new TimerState
                {
                    Phase = legacy.Phase ?? "work", Running = legacy.Running, WorkSeconds = legacy.WorkSeconds, BreakSeconds = legacy.BreakSeconds,
                    Remaining = legacy.Remaining, Deadline = legacy.Deadline, Completed = legacy.Completed
                },
                Checklist = new TaskState
                {
                    Tasks = legacy.Tasks ?? new(), Sections = legacy.Sections ?? new(), ActiveTaskId = legacy.ActiveTaskId,
                    FocusAnchorRemaining = legacy.FocusAnchorRemaining, Version = 5
                },
                X = legacy.X, Y = legacy.Y
            };
        }
        catch (JsonException) { return new(); }
    }

    sealed class LegacyState
    {
        public string? Phase { get; set; }
        public bool Running { get; set; }
        public double WorkSeconds { get; set; } = 1500;
        public double BreakSeconds { get; set; } = 300;
        public double Remaining { get; set; } = 1500;
        public double Deadline { get; set; }
        public int Completed { get; set; }
        public int? X { get; set; }
        public int? Y { get; set; }
        public List<TaskEntry>? Tasks { get; set; }
        public List<TaskSection>? Sections { get; set; }
        public string? ActiveTaskId { get; set; }
        public double FocusAnchorRemaining { get; set; } = -1;
    }
}
