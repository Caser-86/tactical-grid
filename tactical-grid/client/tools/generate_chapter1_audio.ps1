<#
Generates the project's original PCM WAV feedback set. The output is entirely
procedural: no external recordings, samples, or third-party libraries are used.
#>

$ErrorActionPreference = 'Stop'
$sampleRate = 22050
$audioRoot = Join-Path $PSScriptRoot '..\assets\audio'

function Write-Wav {
    param(
        [string]$RelativePath,
        [double]$Frequency,
        [double]$Duration,
        [bool]$IsMusic = $false
    )

    $path = Join-Path $audioRoot $RelativePath
    $directory = Split-Path -Parent $path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $sampleCount = [int]($sampleRate * $Duration)
    $dataBytes = $sampleCount * 2
    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $dataBytes))
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$sampleRate)
        $writer.Write([int]($sampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]$dataBytes)

        for ($i = 0; $i -lt $sampleCount; $i++) {
            $time = $i / [double]$sampleRate
            if ($IsMusic) {
                # A restrained minor arpeggio with a gentle pulse for looping game states.
                $beat = [Math]::Floor($time * 2.0) % 4
                $note = $Frequency * @(1.0, 1.1892, 1.4983, 0.8909)[$beat]
                $pulse = 0.20 + (0.08 * [Math]::Sin(2.0 * [Math]::PI * 2.0 * $time))
                $wave = 0.72 * [Math]::Sin(2.0 * [Math]::PI * $note * $time)
                $wave += 0.28 * [Math]::Sin(2.0 * [Math]::PI * ($note * 0.5) * $time)
                $sample = $wave * $pulse
            } else {
                $envelope = [Math]::Exp(-6.5 * $time / $Duration)
                $chirp = $Frequency * (1.0 - 0.30 * $time / $Duration)
                $wave = [Math]::Sin(2.0 * [Math]::PI * $chirp * $time)
                $wave += 0.25 * [Math]::Sin(2.0 * [Math]::PI * ($chirp * 2.01) * $time)
                $sample = $wave * $envelope * 0.45
            }
            $sample = [Math]::Max(-1.0, [Math]::Min(1.0, $sample))
            $writer.Write([int16]($sample * 32767))
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

$music = @(
    @('bgm/bgm_menu.wav', 146.83),
    @('bgm/bgm_battle_small.wav', 174.61),
    @('bgm/bgm_boss.wav', 110.00),
    @('bgm/bgm_base.wav', 130.81),
    @('bgm/bgm_victory.wav', 220.00),
    @('bgm/bgm_defeat.wav', 92.50)
)
foreach ($track in $music) { Write-Wav $track[0] $track[1] 12.0 $true }

$sfx = @(
    @('sfx/sfx_ui_click.wav', 1320.0, 0.10),
    @('sfx/sfx_ui_hover.wav', 880.0, 0.08),
    @('sfx/sfx_select_unit.wav', 660.0, 0.18),
    @('sfx/sfx_unit_land.wav', 220.0, 0.16),
    @('sfx/sfx_combat_pistol.wav', 170.0, 0.18),
    @('sfx/sfx_hit_flesh.wav', 120.0, 0.14),
    @('sfx/sfx_critical_hit.wav', 980.0, 0.26),
    @('sfx/sfx_unit_down.wav', 95.0, 0.34),
    @('sfx/sfx_explosion.wav', 72.0, 0.42),
    @('sfx/sfx_cover_destroy.wav', 155.0, 0.30),
    @('sfx/sfx_skill_cast.wav', 740.0, 0.30),
    @('sfx/sfx_heal_effect.wav', 530.0, 0.34),
    @('sfx/sfx_overwatch_trigger.wav', 420.0, 0.22),
    @('sfx/sfx_turn_player_start.wav', 392.0, 0.24),
    @('sfx/sfx_turn_enemy_start.wav', 196.0, 0.24),
    @('sfx/sfx_mission_victory.wav', 523.25, 0.60),
    @('sfx/sfx_mission_defeat.wav', 98.0, 0.60),
    @('sfx/sfx_level_up.wav', 784.0, 0.42),
    @('sfx/sfx_item_pickup.wav', 1046.5, 0.20)
)
foreach ($effect in $sfx) { Write-Wav $effect[0] $effect[1] $effect[2] $false }

Write-Host "Generated $($music.Count) music tracks and $($sfx.Count) sound effects in $audioRoot"
