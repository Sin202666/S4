#Requires -Version 5.1
<#
.SYNOPSIS
  Create ArmWrestle game passes / developer products via Roblox Open Cloud, then write Ids back to ArmWrestleConfig.

.DESCRIPTION
  Author: 程莘 (see git user.name)
  Created: 2026-10-15

  Source of truth for the list: scripts/roblox/products.manifest.json
  Each manifest Key must exist in ArmWrestleConfig (_GAME_PASSES / _PRODUCTS) with the same Robux price.

  Modes:
    (default)    Dry run. Validates manifest against ArmWrestleConfig and prints the plan. No network.
    -Apply       Creates missing items. Items whose Name already exists in the universe are reused, not duplicated.
                 Items whose config Id is already non-zero are skipped. Progress is saved after every item
                 to scripts/roblox/products.result.json, so a failed run can simply be re-run.
    -LocalizeZh  After -Apply, set zh name/description via legacy-game-internationalization (Experimental API).
                 Failures are reported but do not abort.
    -WriteBack   Write Ids from products.result.json into ArmWrestleConfig.luau (UTF-8 no BOM, LF).
                 Studio sync is NOT done here; sync the ModuleScript via Studio MCP afterwards.

  API key: read ONLY from env ROBLOX_OPEN_CLOUD_KEY. Never pass it as an argument or commit it.
  Required key permissions (scoped to the target experience): developer products read/write, game passes read/write.

.EXAMPLE
  $env:ROBLOX_OPEN_CLOUD_KEY = "<key>"
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/roblox/CreateRobloxProducts.ps1 -UniverseId 123456
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/roblox/CreateRobloxProducts.ps1 -UniverseId 123456 -Apply -LocalizeZh -WriteBack
#>
param(
    [Parameter(Mandatory = $true)]
    [long]$UniverseId,
    [string]$ManifestPath = "",
    [switch]$Apply,
    [switch]$LocalizeZh,
    [switch]$WriteBack,
    [string]$ZhLanguageCode = "zh-cn"
)

$ErrorActionPreference = "Stop"

$ApiBase = "https://apis.roblox.com"
$MaxRetry = 4
$ScriptDir = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
if (-not $ManifestPath) { $ManifestPath = Join-Path $ScriptDir "products.manifest.json" }
$ResultPath = Join-Path $ScriptDir "products.result.json"
$ConfigPath = Join-Path $RepoRoot "src\ReplicatedFirst\AllSideCode\ToolSystem\ArmWrestleConfig.luau"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$TypeSpec = @{
    GamePass = @{
        CreatePath = "/game-passes/v1/universes/$UniverseId/game-passes"
        ListPath = "/game-passes/v1/universes/$UniverseId/game-passes/creator"
        LocalizePath = "/legacy-game-internationalization/v1/game-passes/{0}/name-description/language-codes/$ZhLanguageCode"
    }
    DeveloperProduct = @{
        CreatePath = "/developer-products/v2/universes/$UniverseId/developer-products"
        ListPath = "/developer-products/v2/universes/$UniverseId/developer-products/creator"
        LocalizePath = "/legacy-game-internationalization/v1/developer-products/{0}/name-description/language-codes/$ZhLanguageCode"
    }
}

function Write-Info([string]$Message) {
    Write-Host "[RobloxProducts] $Message"
}

function Read-Utf8([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
}

function Write-Utf8Lf([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $Utf8NoBom)
}

# Parses `Key = { Id = N, ... Robux = P` rows of ArmWrestleConfig (only keyed rows; arm list rows are unkeyed).
function Get-ConfigRows {
    $rows = @{}
    $pattern = '(?m)^\s*(\w+)\s*=\s*\{\s*Id\s*=\s*(\d+)\s*,[^\n]*?Robux\s*=\s*(\d+)'
    foreach ($m in [regex]::Matches((Read-Utf8 $ConfigPath), $pattern)) {
        $rows[$m.Groups[1].Value] = @{ Id = [long]$m.Groups[2].Value; Robux = [int]$m.Groups[3].Value }
    }
    return $rows
}

function Test-Manifest($Items, $ConfigRows) {
    $errors = @()
    $names = @{}
    foreach ($item in $Items) {
        if (-not $TypeSpec.ContainsKey($item.Type)) { $errors += "$($item.Key): unknown Type '$($item.Type)'" }
        $row = $ConfigRows[$item.Key]
        if (-not $row) { $errors += "$($item.Key): not found in ArmWrestleConfig" }
        elseif ($row.Robux -ne [int]$item.Price) { $errors += "$($item.Key): manifest Price $($item.Price) != config Robux $($row.Robux)" }
        if ([string]::IsNullOrWhiteSpace($item.Name) -or $item.Name.Length -gt 50) { $errors += "$($item.Key): Name empty or longer than 50" }
        $nameKey = "$($item.Type)|$($item.Name)"
        if ($names.ContainsKey($nameKey)) { $errors += "$($item.Key): duplicate Name '$($item.Name)' with $($names[$nameKey])" }
        $names[$nameKey] = $item.Key
    }
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Host "  ERROR $_" -ForegroundColor Red }
        throw "Manifest validation failed ($($errors.Count) errors)."
    }
}

$script:Http = $null
$script:ApiKey = $null

function Initialize-Http {
    $script:ApiKey = $env:ROBLOX_OPEN_CLOUD_KEY
    if ([string]::IsNullOrWhiteSpace($script:ApiKey)) {
        throw "Env ROBLOX_OPEN_CLOUD_KEY is not set."
    }
    Add-Type -AssemblyName System.Net.Http
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $script:Http = New-Object System.Net.Http.HttpClient
    $script:Http.Timeout = [TimeSpan]::FromSeconds(60)
}

# ContentFactory is a scriptblock so a fresh HttpContent is built per retry (content is disposed after send).
function Invoke-Api([string]$Method, [string]$Path, [scriptblock]$ContentFactory = $null) {
    for ($attempt = 1; $attempt -le $MaxRetry; $attempt++) {
        $req = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($Method)), "$ApiBase$Path")
        $req.Headers.Add("x-api-key", $script:ApiKey)
        if ($ContentFactory) { $req.Content = & $ContentFactory }
        $resp = $script:Http.SendAsync($req).GetAwaiter().GetResult()
        $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $status = [int]$resp.StatusCode
        $ok = $resp.IsSuccessStatusCode
        $resp.Dispose()
        $req.Dispose()
        if ($ok) {
            if ([string]::IsNullOrWhiteSpace($body)) { return $null }
            return $body | ConvertFrom-Json
        }
        if (($status -eq 429 -or $status -ge 500) -and $attempt -lt $MaxRetry) {
            $wait = [Math]::Pow(2, $attempt)
            Write-Info "HTTP $status on $Method $Path, retry in ${wait}s"
            Start-Sleep -Seconds $wait
            continue
        }
        throw "HTTP $status $Method $Path : $body"
    }
}

function New-FormContent([hashtable]$Fields) {
    $form = New-Object System.Net.Http.MultipartFormDataContent
    foreach ($k in $Fields.Keys) {
        $form.Add((New-Object System.Net.Http.StringContent([string]$Fields[$k], $Utf8NoBom)), $k)
    }
    # MultipartFormDataContent is IEnumerable; the unary comma stops PowerShell from unrolling it on return.
    return ,$form
}

function New-JsonContent($Object) {
    $json = $Object | ConvertTo-Json -Compress
    return New-Object System.Net.Http.StringContent($json, $Utf8NoBom, "application/json")
}

# Response field names differ between endpoints/versions; accept the known variants.
function Get-ItemId($Item) {
    foreach ($prop in @("productId", "developerProductId", "gamePassId", "id")) {
        $value = $Item.$prop
        if ($value) { return [long]$value }
    }
    return 0
}

function Get-ListItems($Response) {
    foreach ($prop in $Response.PSObject.Properties) {
        if ($prop.Value -is [System.Array]) { return $prop.Value }
    }
    return @()
}

function Get-ExistingByName([string]$ListPath) {
    $map = @{}
    $token = ""
    do {
        $query = "${ListPath}?pageSize=50"
        if ($token) { $query += "&pageToken=$([uri]::EscapeDataString($token))" }
        $res = Invoke-Api "GET" $query
        if (-not $res) { break }
        foreach ($item in (Get-ListItems $res)) {
            $id = Get-ItemId $item
            if ($item.name -and $id -gt 0) { $map[[string]$item.name] = $id }
        }
        $token = $res.nextPageToken
    } while ($token)
    return $map
}

function New-RobloxItem($Item) {
    $spec = $TypeSpec[$Item.Type]
    $fields = @{
        name = $Item.Name
        description = $Item.Description
        isForSale = "true"
        price = [string]$Item.Price
    }
    $res = Invoke-Api "POST" $spec.CreatePath { New-FormContent $fields }
    $id = Get-ItemId $res
    if ($id -le 0) { throw "Create $($Item.Key) returned no id: $($res | ConvertTo-Json -Compress)" }
    return $id
}

function Set-ZhLocalization($Item, [long]$Id) {
    $path = [string]::Format($TypeSpec[$Item.Type].LocalizePath, $Id)
    $body = @{ name = $Item.ZhName; description = $Item.ZhDescription }
    try {
        Invoke-Api "PATCH" $path { New-JsonContent $body } | Out-Null
        return $true
    } catch {
        Write-Host "  WARN zh localization failed for $($Item.Key): $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Read-Result {
    if (-not (Test-Path $ResultPath)) {
        return [pscustomobject]@{ UniverseId = $UniverseId; UpdatedAt = ""; Items = @() }
    }
    return (Read-Utf8 $ResultPath) | ConvertFrom-Json
}

function Save-Result($Result) {
    $Result.UpdatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Utf8Lf $ResultPath (($Result | ConvertTo-Json -Depth 5) + "`n")
}

function Set-ResultItem($Result, $Entry) {
    $Result.Items = @(@($Result.Items | Where-Object { $_.Key -ne $Entry.Key }) + $Entry)
}

function Invoke-Apply($Items, $ConfigRows) {
    Initialize-Http
    $result = Read-Result
    if ([long]$result.UniverseId -ne $UniverseId) {
        throw "products.result.json belongs to universe $($result.UniverseId), not $UniverseId. Move it away first."
    }
    $existing = @{}
    foreach ($type in $TypeSpec.Keys) {
        $existing[$type] = Get-ExistingByName $TypeSpec[$type].ListPath
        Write-Info "Universe has $($existing[$type].Count) existing $type item(s)."
    }
    foreach ($item in $Items) {
        $configId = $ConfigRows[$item.Key].Id
        if ($configId -gt 0) {
            Write-Info "SKIP    $($item.Key): config already has Id $configId"
            continue
        }
        $status = "existing"
        $id = $existing[$item.Type][[string]$item.Name]
        if (-not $id) {
            $id = New-RobloxItem $item
            $status = "created"
        }
        $localized = $false
        if ($LocalizeZh) { $localized = Set-ZhLocalization $item $id }
        Set-ResultItem $result ([pscustomobject]@{
            Key = $item.Key; Type = $item.Type; Name = $item.Name; Price = [int]$item.Price
            Id = [long]$id; Status = $status; ZhLocalized = $localized
        })
        Save-Result $result
        Write-Info ("{0,-8}{1,-18} {2,-17} {3,5} R$  Id={4}" -f $status.ToUpper(), $item.Key, $item.Type, $item.Price, $id)
    }
}

function Invoke-WriteBack {
    if (-not (Test-Path $ResultPath)) { throw "No products.result.json; run with -Apply first." }
    $result = Read-Result
    $text = Read-Utf8 $ConfigPath
    $changed = 0
    foreach ($entry in $result.Items) {
        if ([long]$entry.Id -le 0) { continue }
        $pattern = "(?m)^(\s*$([regex]::Escape($entry.Key))\s*=\s*\{\s*Id\s*=\s*)\d+"
        $hits = [regex]::Matches($text, $pattern).Count
        if ($hits -ne 1) { throw "WriteBack: expected 1 config row for $($entry.Key), found $hits" }
        $text = [regex]::Replace($text, $pattern, "`${1}$([long]$entry.Id)")
        $changed++
    }
    Write-Utf8Lf $ConfigPath $text
    Write-Info "WriteBack: updated $changed Id(s) in ArmWrestleConfig.luau. Sync it to Studio next."
}

$manifest = (Read-Utf8 $ManifestPath) | ConvertFrom-Json
$items = @($manifest.Items)
$configRows = Get-ConfigRows
Test-Manifest $items $configRows
Write-Info "Manifest OK: $($items.Count) item(s), universe $UniverseId."

if (-not $Apply -and -not $WriteBack) {
    foreach ($item in $items) {
        $configId = $configRows[$item.Key].Id
        $note = if ($configId -gt 0) { "skip (config Id $configId)" } else { "create" }
        Write-Host ("  {0,-18} {1,-17} {2,5} R$  {3,-24} {4}" -f $item.Key, $item.Type, $item.Price, $item.Name, $note)
    }
    Write-Info "Dry run only. Add -Apply to create on Roblox."
    return
}

if ($Apply) { Invoke-Apply $items $configRows }
if ($WriteBack) { Invoke-WriteBack }
