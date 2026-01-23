#Requires -Modules Hooks
#Requires -Modules Logging
#Requires -Modules SteamCMD

Write-Log "Updating SteamCMD"

Update-SteamCmd

Start-Sleep -Seconds 2

Write-Log "Starting game installation via SteamCMD"

Invoke-Hook "PreSteamInstallGame"

Install-SteamGame -InstallRoot "$Env:SERVER_DIR" `
                  -AppId $Env:STEAM_APP_ID `
                  -Branch $Env:STEAM_BRANCH `
                  -BranchPassword $Env:STEAM_BRANCH_PASSWORD `
                  -Validate:$([System.Convert]::ToBoolean($Env:STEAM_VALIDATE))

Invoke-Hook "PostSteamInstallGame"