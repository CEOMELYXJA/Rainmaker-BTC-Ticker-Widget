param(
    [Parameter(Mandatory=$true)][string]$ResourcePath,
    [Parameter(Mandatory=$true)][string]$RainmeterExe,
    [Parameter(Mandatory=$true)][string]$Config
)

# Observations are stored locally, never fabricated or backfilled.
$ErrorActionPreference = 'Stop'
$ci = [Globalization.CultureInfo]::InvariantCulture
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$csv = Join-Path $ResourcePath 'history.csv'
$directionFile = Join-Path $ResourcePath 'direction.txt'
$slot = [long]([Math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 300) * 300)
$history = @()
if (Test-Path -LiteralPath $csv) {
    foreach ($line in [IO.File]::ReadAllLines($csv)) {
        $parts = $line.Split(',')
        if ($parts.Length -ne 3) { continue }
        try {
            $t = [long]$parts[0]
            $u = [decimal]::Parse($parts[1], $ci)
            $c = [decimal]::Parse($parts[2], $ci)
            if ($t -ge ($slot - 43200) -and $t -le $slot -and $u -gt 0 -and $c -gt 0) {
                $history += [pscustomobject]@{t=$t; u=$u; c=$c}
            }
        } catch { }
    }
}
$history = @($history | Sort-Object t)
$previous = if ($history.Count) { $history[-1] } else { $null }
$ok = $false
try {
    $a = Invoke-RestMethod 'https://api.coinbase.com/v2/prices/BTC-USD/spot' -TimeoutSec 15
    $b = Invoke-RestMethod 'https://api.coinbase.com/v2/prices/BTC-CAD/spot' -TimeoutSec 15
    $usd = [decimal]::Parse([string]$a.data.amount, $ci)
    $cad = [decimal]::Parse([string]$b.data.amount, $ci)
    if ($usd -le 0 -or $cad -le 0) { throw 'Invalid prices' }
    $ok = $true
} catch { }
$yellow = '255,210,60,255'
$up = '80,220,100,255'
$down = '235,60,60,255'
$cu = $yellow
$cc = $yellow
$status = 'Updated: offline'
if ($ok) {
    if ($previous) {
        if ($usd -gt $previous.u) { $cu=$up } elseif ($usd -lt $previous.u) { $cu=$down }
        if ($cad -gt $previous.c) { $cc=$up } elseif ($cad -lt $previous.c) { $cc=$down }
    }
    $history = @($history | Where-Object { $_.t -ne $slot })
    $history += [pscustomobject]@{t=$slot; u=$usd; c=$cad}
    $history = @($history | Sort-Object t)
    $lines = @($history | ForEach-Object { $_.t.ToString() + ',' + $_.u.ToString($ci) + ',' + $_.c.ToString($ci) })
    [IO.File]::WriteAllLines($csv, [string[]]$lines)
    [IO.File]::WriteAllText($directionFile, "$cu|$cc")
    $status = 'Updated: ' + (Get-Date -Format 'HH:mm')
} elseif ($previous) {
    $usd=$previous.u
    $cad=$previous.c
    if (Test-Path -LiteralPath $directionFile) {
        $directions = [IO.File]::ReadAllText($directionFile).Split('|')
        $allowed = @($yellow,$up,$down)
        if ($directions.Length -eq 2 -and $directions[0] -in $allowed -and $directions[1] -in $allowed) {
            $cu=$directions[0]
            $cc=$directions[1]
        }
    }
}

# Plot only adjacent 5-minute observations, leaving gaps when offline.
$map=@{}
foreach ($row in $history) { $map[[string]$row.t]=$row }
$changes=@{}
$max=0.0
for ($i=0; $i -lt 144; $i++) {
    $t=$slot-(143-$i)*300
    $k=[string]$t
    $p=[string]($t-300)
    if ($map.ContainsKey($k) -and $map.ContainsKey($p)) {
        $d=[double]($map[$k].u-$map[$p].u)
        $changes[$i]=$d
        $max=[Math]::Max($max,[Math]::Abs($d))
    }
}
Add-Type -AssemblyName System.Drawing
$image = [Drawing.Bitmap]::new(144,45)
$graphics = [Drawing.Graphics]::FromImage($image)
$graphics.Clear([Drawing.Color]::FromArgb(10,255,255,255))
$green = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(80,220,100))
$red = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(235,60,60))
for ($i=0; $i -lt 144; $i++) {
    if ($changes.ContainsKey($i) -and $max -gt 0 -and $changes[$i] -ne 0) {
        $h=[int][Math]::Max(1,[Math]::Round([Math]::Abs($changes[$i])/$max*45))
        $brush=if ($changes[$i] -gt 0) { $green } else { $red }
        $graphics.FillRectangle($brush,[int]$i,[int](45-$h),1,$h)
    }
}
$graphics.Dispose()
# Alternate image paths so Rainmeter reloads the changed picture.
$one=Join-Path $ResourcePath 'history-1.png'
$zero=Join-Path $ResourcePath 'history-0.png'
if (!(Test-Path $one) -or ((Test-Path $zero) -and (Get-Item $zero).LastWriteTimeUtc -gt (Get-Item $one).LastWriteTimeUtc)) { $png=$one } else { $png=$zero }
$image.Save($png,[Drawing.Imaging.ImageFormat]::Png)
$image.Dispose()
$green.Dispose()
$red.Dispose()
$us='---'; $cs='---'
if ($ok -or $previous) { $us=$usd.ToString('N0',$ci); $cs=$cad.ToString('N0',$ci) }
& $RainmeterExe '!SetOption' 'meterUSD' 'Text' ('$'+$us) $Config
& $RainmeterExe '!SetOption' 'meterCAD' 'Text' ('$'+$cs) $Config
& $RainmeterExe '!SetOption' 'meterUSD' 'FontColor' $cu $Config
& $RainmeterExe '!SetOption' 'meterCAD' 'FontColor' $cc $Config
& $RainmeterExe '!SetOption' 'meterUpdated' 'Text' $status $Config
& $RainmeterExe '!SetOption' 'meterGraph' 'ImageName' $png $Config
