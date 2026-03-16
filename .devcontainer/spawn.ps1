# spawn.ps1 - Download a fresh copy of the claude-dev repo into a new folder
#
# Usage: .devcontainer\spawn.ps1 <target-directory> [-Git]

param(
    [Parameter(Position = 0)]
    [string]$TargetDir,

    [Alias("g")]
    [switch]$Git
)

$ArchiveUrl = "https://code-alt.sei.cmu.edu/bitbucket/rest/api/latest/projects/CWD/repos/claude-dev/archive?format=zip"

# --- Validate arguments ---

if ([string]::IsNullOrEmpty($TargetDir)) {
    Write-Host "Usage: spawn.ps1 <target-directory> [-Git]"
    Write-Host "Downloads a fresh copy of the claude-dev repo into the target directory."
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Git, -g    Initialize a Git repository after download"
    exit 1
}

# Check git identity if -Git is used
if ($Git) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: 'git' is required when using -Git but is not installed."
        exit 1
    }
    $gitName = git config --global user.name
    $gitEmail = git config --global user.email
    if ([string]::IsNullOrEmpty($gitName) -or [string]::IsNullOrEmpty($gitEmail)) {
        Write-Host "Git identity not configured. Please set your name and email:"
        Write-Host '  git config --global user.name "Your Name"'
        Write-Host '  git config --global user.email "username@sei.cmu.edu"'
        exit 1
    }
}

# Check target directory does not already exist
if (Test-Path $TargetDir) {
    Write-Host "Error: '$TargetDir' already exists."
    exit 1
}

# --- Download and extract ---

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
$TargetDir = (Resolve-Path $TargetDir).Path

$TmpZip = Join-Path ([System.IO.Path]::GetTempPath()) "claude-dev-$(Get-Random).zip"

try {
    Write-Host "Downloading claude-dev..."
    try {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $TmpZip -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "Failed to download archive from:"
        Write-Host "  $ArchiveUrl"
        Remove-Item $TargetDir -ErrorAction SilentlyContinue
        exit 1
    }

    # Extract into target directory
    try {
        Expand-Archive -Path $TmpZip -DestinationPath $TargetDir -ErrorAction Stop
    } catch {
        Write-Host "Failed to extract archive."
        Remove-Item $TargetDir -Recurse -ErrorAction SilentlyContinue
        exit 1
    }

    # Run setup
    Push-Location $TargetDir
    try {
        & .devcontainer\setup.ps1
    } finally {
        Pop-Location
    }

    # Optional git init
    if ($Git) {
        Push-Location $TargetDir
        try {
            git init
            git add -A
            git commit -m "Initial commit"
        } finally {
            Pop-Location
        }
        Write-Host ""
        Write-Host "claude-dev repo spawned to '$TargetDir' with a clean Git repository."
    } else {
        Write-Host ""
        Write-Host "claude-dev repo spawned to '$TargetDir'."
    }

    Write-Host ""
    Write-Host "Now launch Visual Studio Code to build your new dev container:"
    Write-Host ""
    Write-Host "  code $TargetDir"

} finally {
    # Clean up temp zip
    Remove-Item $TmpZip -ErrorAction SilentlyContinue
}
