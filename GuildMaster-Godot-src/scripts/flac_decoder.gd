extends RefCounted

# Windows Media Foundation decodes FLAC to PCM WAV for Godot's audio player.
const WINDOWS_DECODE := """
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType=WindowsRuntime]
[void][Windows.Media.Transcoding.PrepareTranscodeResult, Windows.Media.Transcoding, ContentType=WindowsRuntime]
[void][Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType=WindowsRuntime]

$methods = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetGenericArguments().Count -eq 1
}
$asOperation = $methods | Where-Object { $_.GetParameters()[0].ParameterType.Name.StartsWith('IAsyncOperation') }
$asAction = $methods | Where-Object { $_.GetParameters()[0].ParameterType.Name.StartsWith('IAsyncActionWithProgress') }
function Await-Operation($operation, [type]$resultType) {
    $task = $asOperation.MakeGenericMethod($resultType).Invoke($null, @($operation))
    return $task.GetAwaiter().GetResult()
}

$sourceFile = $null
$targetFile = $null
try {
    $sourceFile = [IO.File]::OpenRead($paths[0])
    $source = [IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($sourceFile)
    $inputProfile = Await-Operation ([Windows.Media.MediaProperties.MediaEncodingProfile]::CreateFromStreamAsync($source)) ([Windows.Media.MediaProperties.MediaEncodingProfile])
    $sourceFile.Position = 0
    $targetFile = [IO.File]::Open($paths[1], 'CreateNew', 'ReadWrite')
    $target = [IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($targetFile)
    $profile = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav('High')
    $profile.Audio.SampleRate = $inputProfile.Audio.SampleRate
    $profile.Audio.ChannelCount = [Math]::Min(2, $inputProfile.Audio.ChannelCount)
    $profile.Audio.BitsPerSample = 16
    $profile.Audio.Bitrate = $profile.Audio.SampleRate * $profile.Audio.ChannelCount * $profile.Audio.BitsPerSample

    $transcoder = [Windows.Media.Transcoding.MediaTranscoder]::new()
    $prepared = Await-Operation ($transcoder.PrepareStreamTranscodeAsync($source, $target, $profile)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
    if (-not $prepared.CanTranscode) { throw $prepared.FailureReason }
    $task = $asAction.MakeGenericMethod([double]).Invoke($null, @($prepared.TranscodeAsync()))
    [void]$task.GetAwaiter().GetResult()
} finally {
    if ($null -ne $targetFile) { $targetFile.Dispose() }
    if ($null -ne $sourceFile) { $sourceFile.Dispose() }
}
"""

static func supported() -> bool:
	return OS.has_feature("windows")

static func start(source: String, output: String) -> int:
	var powershell = OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	var paths = JSON.stringify([source.replace("/", "\\"), output.replace("/", "\\")])
	# Keep file names (including quotes and non-ASCII text) separate from code.
	var data = Marshalls.utf8_to_base64(paths)
	var arguments = "$paths = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('%s')) | ConvertFrom-Json\n" % data
	var command = Marshalls.raw_to_base64((arguments + WINDOWS_DECODE).to_utf16_buffer())
	return OS.create_process(powershell, ["-NoProfile", "-NonInteractive", "-EncodedCommand", command])
