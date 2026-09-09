param(
    [switch]$IncludeEndings,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ffmpeg = 'F:\Path\ffmpeg.exe'
$videoRoot = Join-Path $PSScriptRoot '..\assets\video'

if (-not (Test-Path -LiteralPath $ffmpeg)) {
    throw "ffmpeg was not found at $ffmpeg"
}

# Story-route movies are short scripted effects. Ending movies are included
# only when explicitly requested because their source assets add more than
# 1 GB and should not be silently duplicated in the development checkout.
$names = @('るりコムローイ', '葵フュージョン', '卯ノ花姫の消失', '花火', '佐奈リフレイン', 'ＯＰ')
if ($IncludeEndings) {
    $names += @('ed_aoi', 'ed_hime', 'ed_mahiro', 'ed_ruri', 'ed_sana', 'ed_wakaba', 'ed_yukari')
}

foreach ($name in $names) {
    $source = Join-Path $videoRoot ($name + '.wmv')
    if (-not (Test-Path -LiteralPath $source)) {
        $source = Join-Path $videoRoot ($name + '.mp4')
    }
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Warning "Source movie not found: $name"
        continue
    }
    $target = Join-Path $videoRoot ($name + '.ogv')
    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        Write-Output "Keeping existing $target"
        continue
    }
    Write-Output "Converting $source"
    & $ffmpeg -y -i $source -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 $target
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg failed for $source"
    }
}
