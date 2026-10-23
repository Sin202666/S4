$ErrorActionPreference = "Stop"
$root = "d:\Git\Roblox\A4_Slap\src"
$prefix = "d:\Git\Roblox\A4_Slap\scripts\_tmp_http_serve"
New-Item -ItemType Directory -Force -Path $prefix | Out-Null
$files = @(
	"ReplicatedFirst\AllSideCode\ToolSystem\ArmWrestleConfig.luau",
	"ServerStorage\ServerSideCode\System\SystemArmWrestle\Economy.luau",
	"ReplicatedStorage\ClientSideCode\SystemModule\SystemArmWrestle\MachineShowcase.luau",
	"ReplicatedStorage\ClientSideCode\GuiScripts\ModuleScript\ArmWrestleHUD\Common.luau"
)
foreach ($rel in $files) {
	$name = ($rel -replace "[\\/]", "_").Replace(".luau", "")
	Copy-Item -Force (Join-Path $root $rel) (Join-Path $prefix ($name + ".luau"))
}
Get-ChildItem $prefix -Filter *.luau | ForEach-Object { "$($_.Name) $($_.Length)" }

# Kill previous listener on 8765 if any, then serve
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:18765/")
$listener.Start()
Write-Output "SERVING http://127.0.0.1:18765/"
while ($listener.IsListening) {
	$ctx = $listener.GetContext()
	$path = $ctx.Request.Url.AbsolutePath.TrimStart("/")
	$file = Join-Path $prefix $path
	if (Test-Path $file) {
		$bytes = [System.IO.File]::ReadAllBytes($file)
		$ctx.Response.StatusCode = 200
		$ctx.Response.ContentType = "text/plain; charset=utf-8"
		$ctx.Response.ContentLength64 = $bytes.Length
		$ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
	} else {
		$msg = [System.Text.Encoding]::UTF8.GetBytes("not found: " + $path)
		$ctx.Response.StatusCode = 404
		$ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
	}
	$ctx.Response.Close()
}
