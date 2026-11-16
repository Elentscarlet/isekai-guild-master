# 用法：powershell -File tools\regression\run.ps1 -Tag before
#      对每个界面截一张图，存到 tools\regression\out\<界面>_<Tag>.png
param(
    [string]$Tag = "current",
    [string]$Godot = "C:\Users\yeyiming\Desktop\Godot_v4.7.2-stable_win64.exe"
)
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$failed = @()
foreach ($screen in @("home", "lobby", "room", "table", "dialog")) {
    & $Godot --path $project "res://tools/regression/capture.tscn" -- "--screen=$screen" "--tag=$Tag"
    $file = Join-Path $PSScriptRoot ("out\" + $screen + "_" + $Tag + ".png")
    $deadline = (Get-Date).AddSeconds(25)
    while (-not (Test-Path $file) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path $file)) { $failed += $screen }
}
if ($failed.Count -gt 0) {
    Write-Error ("capture failed: " + ($failed -join ", "))
    exit 1
}
Write-Host "done -> tools/regression/out/*_$Tag.png"
