# RallyCraft automated test suite runner
param(
    [string]$GodotPath = ""
)

function Resolve-GodotExecutable([string]$ExplicitPath) {
    if ($ExplicitPath -and (Test-Path $ExplicitPath)) { return $ExplicitPath }
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $consoleCmd = Get-Command "Godot_v4.6.2-stable_win64_console.exe" -ErrorAction SilentlyContinue
    if ($consoleCmd) { return $consoleCmd.Source }
    $defaultLocal = Join-Path $env:USERPROFILE "Godot\Godot_v4.6.2-stable_win64_console.exe"
    if (Test-Path $defaultLocal) { return $defaultLocal }
    foreach ($cmdName in @("godot4_console", "godot_console", "godot4", "godot")) {
        $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

$godot = Resolve-GodotExecutable $GodotPath
if (-not $godot) {
    Write-Error "Godot 4.6.2 console executable not found. Pass -GodotPath <path>, set `$env:GODOT_BIN, or add godot to PATH."
    exit 1
}

$tests = Get-ChildItem -Path "tests" -Filter "*_test.gd" | Sort-Object Name
$total = $tests.Count
$passed = 0
$failed = 0
$failed_names = @()

Write-Host "`n=== Running RallyCraft Test Suite ($total tests) ===`n" -ForegroundColor Cyan

foreach ($test in $tests) {
    $script_path = "res://tests/$($test.Name)"
    $output = & $godot --headless --path . --script $script_path 2>&1
    $exit_code = $LASTEXITCODE

    # Check for failure: non-zero exit code OR ERROR in output
    $has_error = ($exit_code -ne 0) -or ($output | Select-String -Pattern "ERROR:")
    
    if ($has_error) {
        $failed++
        $failed_names += $test.Name
        Write-Host "FAIL: $($test.Name)" -ForegroundColor Red
        $output | Where-Object { $_ -match "ERROR:|FAIL:" } | ForEach-Object {
            Write-Host "      $_" -ForegroundColor Yellow
        }
    } else {
        $passed++
        Write-Host "PASS: $($test.Name)" -ForegroundColor Green
    }
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$pass_color = if ($passed -eq $total) { "Green" } else { "Yellow" }
Write-Host "Passed: $passed / $total" -ForegroundColor $pass_color
if ($failed -gt 0) {
    Write-Host "Failed: $failed / $total ($($failed_names -join ', '))" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests passed successfully!`n" -ForegroundColor Green
    exit 0
}
