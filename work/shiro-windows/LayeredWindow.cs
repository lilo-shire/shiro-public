using System.ComponentModel;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace Shiro;

internal class LayeredWindow : Form
{
    [StructLayout(LayoutKind.Sequential)] struct NativePoint { public int X, Y; public NativePoint(int x, int y) { X = x; Y = y; } }
    [StructLayout(LayoutKind.Sequential)] struct NativeSize { public int Width, Height; public NativeSize(int width, int height) { Width = width; Height = height; } }
    [StructLayout(LayoutKind.Sequential, Pack = 1)] struct Blend { public byte Operation, Flags, Alpha, Format; }
    [DllImport("user32.dll", SetLastError = true)] static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr dstDC, ref NativePoint dst, ref NativeSize size, IntPtr srcDC, ref NativePoint src, uint colorKey, ref Blend blend, uint flags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("gdi32.dll", SetLastError = true)] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
    [DllImport("gdi32.dll", SetLastError = true)] static extern IntPtr CreateDIBSection(IntPtr dc, ref BitmapInfo info, uint usage, out IntPtr pixels, IntPtr section, uint offset);
    [StructLayout(LayoutKind.Sequential)] struct BitmapInfo
    {
        public uint HeaderSize;
        public int Width, Height;
        public ushort Planes, BitCount;
        public uint Compression, ImageSize;
        public int XPixels, YPixels;
        public uint ColorsUsed, ColorsImportant;
    }
    IntPtr memoryDC, dib, oldObject;
    Bitmap? surface;
    protected override bool ShowWithoutActivation => true;
    protected override CreateParams CreateParams
    {
        get { var p = base.CreateParams; p.ExStyle |= 0x80000 | 0x80; return p; } // layered + tool window
    }
    protected void CreateSurface(int width, int height)
    {
        ReleaseSurface();
        var screen = GetDC(IntPtr.Zero);
        try
        {
            memoryDC = CreateCompatibleDC(screen);
            var info = new BitmapInfo { HeaderSize = 40, Width = width, Height = -height, Planes = 1, BitCount = 32 };
            dib = CreateDIBSection(screen, ref info, 0, out var pixels, IntPtr.Zero, 0);
            if (memoryDC == IntPtr.Zero || dib == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            oldObject = SelectObject(memoryDC, dib);
            surface = new Bitmap(width, height, width * 4, PixelFormat.Format32bppPArgb, pixels);
        }
        finally { ReleaseDC(IntPtr.Zero, screen); }
    }
    protected void Present(Action<Graphics> draw)
    {
        if (surface == null) CreateSurface(Width, Height);
        using (var g = Graphics.FromImage(surface!))
        {
            g.Clear(Color.Transparent);
            draw(g);
        }
        var dst = new NativePoint(Left, Top); var src = new NativePoint(0, 0);
        var size = new NativeSize(surface!.Width, surface.Height);
        var blend = new Blend { Operation = 0, Alpha = 255, Format = 1 };
        if (!UpdateLayeredWindow(Handle, IntPtr.Zero, ref dst, ref size, memoryDC, ref src, 0, ref blend, 2))
            throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    void ReleaseSurface()
    {
        surface?.Dispose(); surface = null;
        if (memoryDC != IntPtr.Zero && oldObject != IntPtr.Zero) SelectObject(memoryDC, oldObject);
        if (dib != IntPtr.Zero) DeleteObject(dib);
        if (memoryDC != IntPtr.Zero) DeleteDC(memoryDC);
        memoryDC = dib = oldObject = IntPtr.Zero;
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) ReleaseSurface();
        base.Dispose(disposing);
    }
}
