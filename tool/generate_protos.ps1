$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$protoDir = Join-Path $repo "protos"
$outDir = Join-Path $repo "lib\src\proto\generated"
$defaultProtoc = "C:\Users\oldre\AppData\Local\Microsoft\WinGet\Packages\Google.Protobuf_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\protoc.exe"

New-Item -ItemType Directory -Force $outDir | Out-Null

$pluginDir = Join-Path $env:LOCALAPPDATA "Pub\Cache\global_packages\protoc_plugin\bin"
$snapshot = Get-ChildItem $pluginDir -Filter "protoc_plugin.dart-*.snapshot" -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if ($null -eq $snapshot) {
  dart pub global activate protoc_plugin
  $snapshot = Get-ChildItem $pluginDir -Filter "protoc_plugin.dart-*.snapshot" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

$plugin = Join-Path $env:TEMP "protoc-gen-dart-ble-prov.cmd"
Set-Content -LiteralPath $plugin -Value "@echo off`r`ndart `"$($snapshot.FullName)`" %*`r`n" -Encoding ascii

$protoc = if (Test-Path $defaultProtoc) { $defaultProtoc } else { "protoc" }
$protoFiles = Get-ChildItem $protoDir -Filter "*.proto" | ForEach-Object { $_.Name }
& $protoc --plugin="protoc-gen-dart=$plugin" --dart_out="$outDir" --proto_path="$protoDir" @protoFiles
