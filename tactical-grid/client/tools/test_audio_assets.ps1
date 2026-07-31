<#
Validates the procedurally generated WAV source files before a release build.
This is a technical check only; it cannot replace a human listening review.
#>
[CmdletBinding()]
param(
    [string]$AudioRoot = ''
)
if (-not $AudioRoot) {
    $root = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
    $AudioRoot = Join-Path $root '..\assets\audio'
}

$ErrorActionPreference = 'Stop'
$expected = @(
    'bgm/bgm_menu.wav', 'bgm/bgm_battle_stealth.wav', 'bgm/bgm_battle_engaged.wav',
    'bgm/bgm_battle_alert.wav', 'bgm/bgm_battle_small.wav', 'bgm/bgm_boss.wav',
    'bgm/bgm_base.wav', 'bgm/bgm_victory.wav', 'bgm/bgm_defeat.wav',
    'sfx/sfx_ui_click.wav', 'sfx/sfx_ui_hover.wav', 'sfx/sfx_select_unit.wav',
    'sfx/sfx_unit_land.wav', 'sfx/sfx_combat_pistol.wav', 'sfx/sfx_combat_shotgun.wav',
    'sfx/sfx_combat_smg.wav', 'sfx/sfx_combat_blade.wav', 'sfx/sfx_combat_sniper.wav',
    'sfx/sfx_combat_machine_gun.wav', 'sfx/sfx_combat_launcher.wav', 'sfx/sfx_combat_medical.wav',
    'sfx/sfx_hit_flesh.wav', 'sfx/sfx_critical_hit.wav', 'sfx/sfx_unit_down.wav',
    'sfx/sfx_explosion.wav', 'sfx/sfx_cover_destroy.wav', 'sfx/sfx_skill_cast.wav',
    'sfx/sfx_heal_effect.wav', 'sfx/sfx_overwatch_trigger.wav', 'sfx/sfx_turn_player_start.wav',
    'sfx/sfx_turn_enemy_start.wav', 'sfx/sfx_mission_victory.wav', 'sfx/sfx_mission_defeat.wav',
    'sfx/sfx_level_up.wav', 'sfx/sfx_item_pickup.wav',
    'sfx/sfx_network_scan.wav', 'sfx/sfx_network_takeover.wav', 'sfx/sfx_network_disable.wav', 'sfx/sfx_network_overload.wav', 'sfx/sfx_alert_rise.wav', 'sfx/sfx_camera_reveal.wav', 'sfx/sfx_turret_reversal.wav', 'sfx/sfx_beacon_delay.wav'
)

$hashes = @{}
foreach ($relativePath in $expected) {
    $path = Join-Path $AudioRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing audio asset: $relativePath"
    }

    $reader = [System.IO.BinaryReader]::new([System.IO.File]::OpenRead($path))
    try {
        $riff = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        [void]$reader.ReadInt32()
        $wave = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $fmt = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $fmtSize = $reader.ReadInt32()
        $format = $reader.ReadInt16()
        $channels = $reader.ReadInt16()
        $sampleRate = $reader.ReadInt32()
        [void]$reader.ReadInt32()
        [void]$reader.ReadInt16()
        $bitsPerSample = $reader.ReadInt16()
        if ($fmtSize -gt 16) { [void]$reader.ReadBytes($fmtSize - 16) }
        $data = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
        $dataBytes = $reader.ReadInt32()
        if ($riff -ne 'RIFF' -or $wave -ne 'WAVE' -or $fmt -ne 'fmt ' -or $data -ne 'data') {
            throw "Invalid WAV container: $relativePath"
        }
        if ($format -ne 1 -or $channels -ne 1 -or $sampleRate -ne 22050 -or $bitsPerSample -ne 16 -or $dataBytes -le 0) {
            throw "Unexpected WAV format: $relativePath"
        }

        $peak = 0
        $samplesToRead = [Math]::Min([int]($dataBytes / 2), 4096)
        for ($sampleIndex = 0; $sampleIndex -lt $samplesToRead; $sampleIndex++) {
            $value = [Math]::Abs([int]$reader.ReadInt16())
            if ($value -gt $peak) { $peak = $value }
        }
        if ($peak -lt 256) { throw "Near-silent audio asset: $relativePath" }
    } finally {
        $reader.Dispose()
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($hashes.ContainsKey($hash)) {
        throw "Duplicate audio content: $relativePath and $($hashes[$hash])"
    }
    $hashes[$hash] = $relativePath
}

Write-Host "Audio technical QA passed: $($expected.Count) original PCM WAV files"
