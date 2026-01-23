Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-SteamCmd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $SteamCmdPath,
        [Parameter(Mandatory)] [string[]] $Arguments
    )

    Set-Location /opt/steamcmd

    & ./steamcmd.sh $arguments
}

function Update-SteamCmd {
    Invoke-SteamCmd -SteamCmdPath "steamcmd" -Arguments @("+@sSteamCmdForcePlatformType linux", "+quit")
}

function Install-SteamGame {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int] $AppId,

        [Parameter(Mandatory)]
        [string] $InstallRoot,

        [Parameter()]
        [string] $SteamCmdPath = "steamcmd",

        [Parameter()]
        [string] $Username = "anonymous",

        [Parameter()]
        [string] $Password = "",

        [Parameter()]
        [string] $Branch = "",

        [Parameter()]
        [string] $BranchPassword = "",

        [Parameter()]
        [switch] $Validate
    )

    # ---- Install ----
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

    $steamCmdArgs = @(
        "+@ShutdownOnFailedCommand", "1",
        "+@NoPromptForPassword", "1",
        "+@sSteamCmdForcePlatformType", "linux",
        "+force_install_dir", $InstallRoot,
        "+login", $Username
    )

    if ($Username -ne "anonymous" -and $Password) {
        $steamCmdArgs += $Password
    }

    $steamCmdArgs += "+app_update", $AppId

    if ($Branch) {
        $steamCmdArgs += "-beta", $Branch
        if ($BranchPassword) {
            $steamCmdArgs += "-betapassword", $BranchPassword
        }
    }

    if ($Validate) {
        $steamCmdArgs += "validate"
    }

    $steamCmdArgs += "+quit"

    Invoke-SteamCmd -SteamCmdPath $SteamCmdPath -Arguments $steamCmdArgs
}

Export-ModuleMember -Function Install-SteamGame
Export-ModuleMember -Function Update-SteamCmd