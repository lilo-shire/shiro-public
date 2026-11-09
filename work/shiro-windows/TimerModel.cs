namespace Shiro;

// One countdown with two slots: the visible phase ("work" or "break") and the other phase,
// whose remaining time is kept in OtherRemaining while it is not shown. Same rules as the macOS version.
public sealed class TimerState
{
    public string Phase { get; set; } = "work";
    public bool Running { get; set; }
    public double WorkSeconds { get; set; } = 1200;
    public double BreakSeconds { get; set; } = 420;
    public double Remaining { get; set; } = 1200;
    public double OtherRemaining { get; set; } = -1;
    public double Deadline { get; set; }
    public int Completed { get; set; }
}

public sealed class TimerModel
{
    public TimerState State { get; }
    public TimerModel(TimerState? state = null)
    {
        State = state ?? new();
        State.Phase = State.Phase == "break" ? "break" : "work";
        State.WorkSeconds = Math.Clamp(Finite(State.WorkSeconds, 1200), 60, 10800);
        State.BreakSeconds = Math.Clamp(Finite(State.BreakSeconds, 420), 60, 3600);
        double full = DurationOf(State.Phase), otherFull = DurationOf(Other(State.Phase));
        State.Remaining = Math.Clamp(Finite(State.Remaining, full), 0, full);
        State.OtherRemaining = State.OtherRemaining <= 0 || !double.IsFinite(State.OtherRemaining) ? otherFull : Math.Min(State.OtherRemaining, otherFull);
        State.Running &= double.IsFinite(State.Deadline) && State.Deadline > 0;
        if (!State.Running) State.Deadline = 0;
        State.Completed = Math.Max(0, State.Completed);
    }
    static double Finite(double value, double fallback) => double.IsFinite(value) ? value : fallback;
    static string Other(string phase) => phase == "work" ? "break" : "work";
    public double DurationOf(string phase) => phase == "break" ? State.BreakSeconds : State.WorkSeconds;
    public double RemainingAt(double now) => State.Running ? Math.Max(0, State.Deadline - now) : State.Remaining;
    public bool IsPartialAt(double now) => RemainingAt(now) < DurationOf(State.Phase) - .5;
    public void Start(double now)
    {
        if (State.Running) return;
        if (State.Remaining <= 0) State.Remaining = DurationOf(State.Phase);
        State.Deadline = now + State.Remaining;
        State.Running = true;
    }
    public void Pause(double now)
    {
        if (!State.Running) return;
        State.Remaining = RemainingAt(now);
        State.Running = false; State.Deadline = 0;
    }
    // Returns "workFinished" or "breakFinished" once; the next phase always waits for a manual start.
    public string? Tick(double now)
    {
        if (!State.Running || now < State.Deadline) return null;
        State.Running = false; State.Deadline = 0;
        if (State.Phase == "work")
        {
            State.Completed++;
            State.Phase = "break"; State.Remaining = State.BreakSeconds; State.OtherRemaining = State.WorkSeconds;
            return "workFinished";
        }
        // A focus interval paused by switching to the break continues where it stopped.
        State.Phase = "work";
        State.Remaining = State.OtherRemaining > 0 ? State.OtherRemaining : State.WorkSeconds;
        State.OtherRemaining = State.BreakSeconds;
        return "breakFinished";
    }
    public void SwitchTo(string phase, double now)
    {
        phase = phase == "break" ? "break" : "work";
        if (phase == State.Phase) return;
        Pause(now);
        double shown = State.Remaining;
        State.Remaining = State.OtherRemaining > 0 ? State.OtherRemaining : DurationOf(phase);
        State.OtherRemaining = shown > 0 ? shown : DurationOf(State.Phase);
        State.Phase = phase;
    }
    public void Reset() { State.Running = false; State.Deadline = 0; State.Remaining = DurationOf(State.Phase); }
    public double WorkRemainingAt(double now) => State.Phase == "work" ? RemainingAt(now) : State.OtherRemaining;
    // Loads a saved focus time (negative: a fresh interval) and stops the countdown if it shows focus.
    public void LoadWorkRemaining(double value, double now)
    {
        double next = !double.IsFinite(value) || value <= 0 ? State.WorkSeconds : Math.Min(value, State.WorkSeconds);
        if (State.Phase == "work") { Pause(now); State.Remaining = next; }
        else State.OtherRemaining = next;
    }
    public void SetMinutes(double work, double rest)
    {
        double oldWork = State.WorkSeconds, oldBreak = State.BreakSeconds;
        State.WorkSeconds = Math.Round(Math.Clamp(Finite(work, 20), 1, 180), MidpointRounding.AwayFromZero) * 60;
        State.BreakSeconds = Math.Round(Math.Clamp(Finite(rest, 7), 1, 60), MidpointRounding.AwayFromZero) * 60;
        // An untouched slot follows the new length; a started one keeps its time but never exceeds the new length.
        static double Adjust(double value, double oldFull, double newFull) => value >= oldFull - .5 ? newFull : Math.Min(value, newFull);
        bool work_ = State.Phase == "work";
        if (!State.Running) State.Remaining = Adjust(State.Remaining, work_ ? oldWork : oldBreak, work_ ? State.WorkSeconds : State.BreakSeconds);
        State.OtherRemaining = Adjust(State.OtherRemaining, work_ ? oldBreak : oldWork, work_ ? State.BreakSeconds : State.WorkSeconds);
    }
}

