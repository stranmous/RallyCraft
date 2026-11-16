# RallyCraft Desktop Dynamic Verification Harness (Scenario Runner)
param(
    [string]$Scenario = "",
    [switch]$All,
    [switch]$List,
    [switch]$Headless,
    [switch]$Windowed = $true,
    [string]$OutDir = "build/scenario_runs",
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

$scenarioMap = [ordered]@{
    "AccelBrakeReverse"   = "res://tests/scenarios/scenario_accel_brake_reverse.gd"
    "CorneringDrift"      = "res://tests/scenarios/scenario_cornering_drift.gd"
    "AiPackOvertake"      = "res://tests/scenarios/scenario_ai_pack_overtake.gd"
    "BoundaryRecovery"    = "res://tests/scenarios/scenario_boundary_recovery.gd"
    "BoostPickup"         = "res://tests/scenarios/scenario_boost_pickup.gd"
    "CollisionSeparation" = "res://tests/scenarios/scenario_collision_separation.gd"
    "ScreensFlow"         = "res://tests/scenarios/scenario_screens_flow.gd"
    "BiomeShowcase"       = "res://tests/scenarios/scenario_biome_showcase.gd"
}

if ($List) {
    Write-Host "`nAvailable Desktop Verification Scenarios:" -ForegroundColor Cyan
    foreach ($key in $scenarioMap.Keys) {
        Write-Host ("  - {0,-22} ({1})" -f $key, $scenarioMap[$key]) -ForegroundColor White
    }
    Write-Host "`nUsage:" -ForegroundColor Cyan
    Write-Host "  .\run_scenario.ps1 -Scenario AccelBrakeReverse"
    Write-Host "  .\run_scenario.ps1 -All"
    Write-Host "  .\run_scenario.ps1 -All -Headless`n"
    exit 0
}

$targets = @()
if ($All) {
    $targets = @($scenarioMap.Keys)
} elseif ($Scenario -ne "") {
    $matched = $scenarioMap.Keys | Where-Object { $_ -ieq $Scenario -or ("scenario_" + $_) -ieq ($Scenario -replace "_","") }
    if (-not $matched) {
        # Fallback: look up file directly in tests/scenarios/
        $candidate = "tests/scenarios/scenario_$($Scenario.ToLower()).gd"
        if (Test-Path $candidate) {
            $scenarioMap[$Scenario] = "res://$candidate"
            $targets = @($Scenario)
        } else {
            Write-Error "Unknown scenario '$Scenario'. Run .\run_scenario.ps1 -List to see available scenarios."
            exit 1
        }
    } else {
        $targets = @($matched)
    }
} else {
    Write-Host "Specify -Scenario <Name>, -All, or -List." -ForegroundColor Yellow
    exit 1
}

$useHeadless = $Headless.IsPresent
$modeLabel = if ($useHeadless) { "HEADLESS (60Hz fixed)" } else { "WINDOWED (1280x720 live + frame capture)" }

Write-Host "`n=== RallyCraft Scenario Runner [$modeLabel] ===" -ForegroundColor Cyan

$passed = 0
$failed = 0
$failedNames = @()

foreach ($name in $targets) {
    $scriptRes = $scenarioMap[$name]
    $absOut = Join-Path (Get-Location).Path "$OutDir/$name"
    New-Item -ItemType Directory -Force -Path $absOut | Out-Null

    Write-Host "`n>>> Running Scenario: $name ($scriptRes)" -ForegroundColor Cyan

    $argsList = @("--fixed-fps", "60", "--path", ".")
    if ($useHeadless) {
        $argsList = @("--headless") + $argsList
    } else {
        $argsList += @("--resolution", "1280x720")
    }
    $argsList += @("--script", $scriptRes, "--", "--out=$absOut")

    $output = & $godot @argsList 2>&1
    $exitCode = $LASTEXITCODE

    foreach ($line in $output) {
        $text = $line.ToString()
        if ($text -match "^\s*FAIL\b|SCRIPT ERROR:|Parse Error:") {
            Write-Host $text -ForegroundColor Red
        } elseif ($text -match "^\s*WARN\b") {
            Write-Host $text -ForegroundColor Yellow
        } elseif ($text -match "^\s*PASS\b|^=== .*: PASS") {
            Write-Host $text -ForegroundColor Green
        } elseif ($text -match "^\[TELEMETRY") {
            Write-Host $text -ForegroundColor Gray
        } elseif ($text -match "^\s*METRIC\b|^===") {
            Write-Host $text -ForegroundColor Cyan
        }
    }

    $hasScriptError = [bool]($output | Select-String -Pattern "SCRIPT ERROR:|Parse Error:")
    if ($exitCode -ne 0 -or $hasScriptError) {
        $failed++
        $failedNames += $name
        Write-Host "RESULT: FAIL ($name)" -ForegroundColor Red
    } else {
        $passed++
        Write-Host "RESULT: PASS ($name) -> $absOut" -ForegroundColor Green
    }
}

Write-Host "`n=== Scenario Summary ===" -ForegroundColor Cyan
Write-Host ("Passed: {0} / {1}" -f $passed, $targets.Count) -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
if ($failed -gt 0) {
    Write-Host ("Failed: {0} ({1})" -f $failed, ($failedNames -join ", ")) -ForegroundColor Red
    exit 1
}
exit 0
