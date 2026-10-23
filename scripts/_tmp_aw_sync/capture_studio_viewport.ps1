# Capture Roblox Studio 3D viewport (prefer ~16:9 inset child) to JPEG.
param(
	[Parameter(Mandatory = $true)][string]$OutPath
)

$ErrorActionPreference = "Stop"

$code = @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public class StudioCapVp {
	public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc f, IntPtr l);
	[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
	[DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
	[DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
	[DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
	[DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr d, int x, int y, int w, int h, IntPtr s, int sx, int sy, int rop);
	[DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleDC(IntPtr dc);
	[DllImport("gdi32.dll")] public static extern IntPtr CreateCompatibleBitmap(IntPtr dc, int w, int h);
	[DllImport("gdi32.dll")] public static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
	[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
	[DllImport("gdi32.dll")] public static extern bool DeleteDC(IntPtr dc);
	public const int SRCCOPY = 0x00CC0020;
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
	[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

	public class Cand {
		public IntPtr H;
		public int W;
		public int Ht;
		public double Ratio;
		public double Score;
	}

	public static IntPtr FindMain(int pid) {
		IntPtr found = IntPtr.Zero;
		EnumWindows((h, l) => {
			uint p; GetWindowThreadProcessId(h, out p);
			if ((int)p != pid || !IsWindowVisible(h)) return true;
			var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
			if (sb.ToString().IndexOf("Roblox Studio", StringComparison.OrdinalIgnoreCase) >= 0) { found = h; return false; }
			return true;
		}, IntPtr.Zero);
		return found;
	}

	// Prefer landscape ~16:9 inset views over full-width chrome containers.
	public static Cand FindViewport(IntPtr parent) {
		Cand best = null;
		EnumChildWindows(parent, (h, l) => {
			if (!IsWindowVisible(h)) return true;
			RECT cr; GetClientRect(h, out cr);
			int w = cr.Right - cr.Left, ht = cr.Bottom - cr.Top;
			if (w < 900 || ht < 500) return true;
			double ratio = (double)w / Math.Max(ht, 1);
			if (ratio < 1.5 || ratio > 2.05) return true;
			// Score: closeness to 16:9 plus modest size bonus
			double score = 1000.0 - Math.Abs(ratio - 16.0 / 9.0) * 400.0 + Math.Min(w, 1800) * 0.01;
			if (best == null || score > best.Score) {
				best = new Cand { H = h, W = w, Ht = ht, Ratio = ratio, Score = score };
			}
			return true;
		}, IntPtr.Zero);
		return best;
	}

	public static bool Capture(IntPtr hWnd, string path) {
		RECT cr; GetClientRect(hWnd, out cr);
		int w = cr.Right - cr.Left, h = cr.Bottom - cr.Top;
		if (w <= 0 || h <= 0) return false;
		POINT pt = new POINT(); ClientToScreen(hWnd, ref pt);
		IntPtr screen = GetDC(IntPtr.Zero);
		IntPtr mem = CreateCompatibleDC(screen);
		IntPtr hbmp = CreateCompatibleBitmap(screen, w, h);
		IntPtr old = SelectObject(mem, hbmp);
		BitBlt(mem, 0, 0, w, h, screen, pt.X, pt.Y, SRCCOPY);
		SelectObject(mem, old); DeleteDC(mem); ReleaseDC(IntPtr.Zero, screen);
		using (var bmp = Image.FromHbitmap(hbmp)) {
			DeleteObject(hbmp);
			ImageCodecInfo jpg = null;
			foreach (var c in ImageCodecInfo.GetImageDecoders()) {
				if (c.FormatID == ImageFormat.Jpeg.Guid) { jpg = c; break; }
			}
			var ep = new EncoderParameters(1);
			ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 92L);
			bmp.Save(path, jpg, ep);
		}
		return true;
	}
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing -ErrorAction Stop

$proc = Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -match 'Roblox Studio' } | Select-Object -First 1
if (-not $proc) { throw "Roblox Studio process not found" }
$main = [StudioCapVp]::FindMain($proc.Id)
if ($main -eq [IntPtr]::Zero) { throw "Studio main window not found" }
$vp = [StudioCapVp]::FindViewport($main)
if ($null -eq $vp) { throw "Viewport child not found" }

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

if (-not [StudioCapVp]::Capture($vp.H, $OutPath)) { throw "Capture failed" }
$item = Get-Item $OutPath
Write-Output ("OK hwnd=0x{0:X} {1}x{2} ratio={3:F2} bytes={4} path={5}" -f $vp.H.ToInt64(), $vp.W, $vp.Ht, $vp.Ratio, $item.Length, $item.FullName)
