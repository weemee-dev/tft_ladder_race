param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$Platforms = "android,ios,web,macos,windows"
)

$ErrorActionPreference = "Stop"

Write-Host "Reconfiguring FlutterFire for project '$ProjectId'..."

dart pub global run flutterfire_cli:flutterfire configure `
    --project="$ProjectId" `
    --platforms="$Platforms" `
    --yes

Write-Host "Done. Firebase config regenerated for project '$ProjectId'."
