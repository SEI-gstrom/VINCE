# Claude Code Dev Container Setup Script for Windows

param(
    [string]$Profile
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DevEnv = Join-Path $ScriptDir "devcontainer.env"

# initial setup
if (-not (Test-Path $DevEnv)) {
    $Example = Join-Path $ScriptDir "profile.env.$Profile"

    # select profile if example not valid
    if (-not (Test-Path $Example)) {
        Write-Host ""
        Write-Host "Select Claude Profile"
        $profiles = @(Get-ChildItem -Path $ScriptDir -Filter "profile.env.*" | ForEach-Object {
            $_.Name -replace '^profile\.env\.', ''
        } | Sort-Object)

        for ($i = 0; $i -lt $profiles.Count; $i++) {
            Write-Host "  $($i + 1). $($profiles[$i])"
        }

        do {
            $selection = Read-Host "Enter selection"
            $index = [int]$selection - 1
        } while ($index -lt 0 -or $index -ge $profiles.Count)

        $Profile = $profiles[$index]
        $Example = Join-Path $ScriptDir "profile.env.$Profile"
    }

    Copy-Item $Example $DevEnv
    Remove-Item "$ScriptDir\profile.env.*"
}

Write-Host ""
Write-Host "  Configure Amazon Bedrock Access"
Write-Host ""

$KeyId = Read-Host "AWS Access Key ID"
if ([string]::IsNullOrEmpty($KeyId)) {
    Write-Host "ERROR: Access Key ID required."
    exit 1
}

$SecureSecret = Read-Host "AWS Secret Access Key" -AsSecureString
$Secret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureSecret)
)
if ([string]::IsNullOrEmpty($Secret)) {
    Write-Host "ERROR: Secret Access Key required."
    exit 1
}

# update api key
(Get-Content $DevEnv) |
    ForEach-Object {
        $_ -replace '(AWS_ACCESS_KEY_ID=).*', "`${1}$KeyId" `
           -replace '(AWS_SECRET_ACCESS_KEY=).*', "`${1}$Secret"
    } | Set-Content $DevEnv

Write-Host ""
Write-Host "Created: .devcontainer/devcontainer.env"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  If outside container: Open in VS Code -> F1 -> 'Dev Containers: Reopen in Container'"
Write-Host "  If inside container:  F1 -> 'Dev Containers: Rebuild Container'"
Write-Host ""
