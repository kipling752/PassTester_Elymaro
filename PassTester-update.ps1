#################################################################
#####                                                       #####
#####  Must be executed from a Domain Admin account         #####
#####                                                       #####
#####  Developped by Elymaro                                #####
#####  Optimized by [Votre Nom]                             #####
#################################################################

clear

Start-Transcript -Path "$env:USERPROFILE\Desktop\PassTester_log.txt" -Append | Out-Null

Write-Host " _____         _____ _____ _______ ______  _____ _______ ______ _____  "
Write-Host "|  __ \ /\    / ____/ ____|__   __|  ____|/ ____|__   __|  ____|  __ \ "
Write-Host "| |__) /  \  | (___| (___    | |  | |__  | (___    | |  | |__  | |__) |"
Write-Host "|  ___/ /\ \  \___ \\___ \   | |  |  __|  \___ \   | |  |  __| |  _  / "
Write-Host "| |  / ____ \ ____) |___) |  | |  | |____ ____) |  | |  | |____| | \ \ "
Write-Host "|_| /_/    \_\_____/_____/   |_|  |______|_____/   |_|  |______|_|  \_\`n"

if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "Must be opened from a Domain Admin account !" -ForegroundColor Red
    Stop-Transcript | Out-Null
    Start-Sleep 5
    exit
}

function date {
    (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$directory_audit = "$env:USERPROFILE\Desktop\PassTester"
$directory_exports_NTDS = "$directory_audit\NTDS"

function DSInternals {
    if(Get-Module DSInternals) {
        Import-Module DSInternals
    } else {
        Install-Module -Name DSInternals -Force -Confirm:$false
    }
}

function NTDS_copy {
    if (!(Test-Path $directory_audit)) {
        Write-Host "$(date) - Creating directories"
        New-Item -ItemType Directory -Path $directory_audit | Out-Null
    }

    if ((Get-ChildItem $directory_audit) -ne $null) {
        Write-Host "$(date) - Folder $directory_audit is not empty !" -ForegroundColor Yellow
        Stop-Transcript | Out-Null
        Start-Sleep 5
        exit
    } else {
        New-Item -ItemType Directory -Path "$directory_audit\results" | Out-Null
        New-Item -ItemType Directory -Path "$directory_exports_NTDS" | Out-Null
    }

    if ($env:LOGONSERVER.Substring(2) -ne $env:COMPUTERNAME) {
        New-SmbShare -Path $directory_exports_NTDS -Name "Share_Audit" -FullAccess (Get-LocalGroup -SID "S-1-5-32-544").name

        $Partage = "\\$env:COMPUTERNAME\Share_Audit"
        $session = New-PSSession -ComputerName $env:LOGONSERVER.Substring(2) -Name Audit
        Write-Host "$(date) - Extracting NTDS database ..."
        Invoke-Command -Session $session -ScriptBlock {
            param($Partage)
            NTDSUTIL "Activate Instance NTDS" "IFM" "Create Full $Partage" "q" "q"
        } -ArgumentList $Partage | Out-Null

        Remove-SmbShare -Name "Share_Audit" -Force
    } else {
        Write-Host "$(date) - Extracting NTDS database ..."
        NTDSUTIL "Activate Instance NTDS" "IFM" "Create Full $directory_exports_NTDS" "q" "q"
    }

    Write-Host "$(date) - NTDS database decryption"
    $Key = Get-BootKey -SystemHiveFilePath "$directory_exports_NTDS\registry\SYSTEM"

    Get-ADDBAccount -BootKey $Key -DatabasePath "$directory_exports_NTDS\Active Directory\ntds.dit" -All |
    Format-Custom -View HashcatNT | Out-File "$directory_audit\Hashdump.txt"

    $NTDS = Get-Content "$directory_audit\Hashdump.txt"
    $NTDS | Where-Object { $_ -ne '' -and $_ -notmatch "krbtgt" -and $_ -notmatch "\$" } | 
    Get-Random -Count $NTDS.Count | Set-Content "$directory_audit\Hashdump_cleared.txt"

    Write-Host "$(date) - Extract Done !"
}

function Password_Control {
    if (!(Test-Path "$directory_audit\Hashdump_cleared.txt")) {
        Write-Host "No file $directory_audit\Hashdump_cleared.txt present !" -ForegroundColor Red
        Start-Sleep 10
        Exit
    }
    $NTDS = Get-Content "$directory_audit\Hashdump_cleared.txt"
    $total_users = $NTDS.count
    $compromised_count = 0
    $empty_count = 0

    Write-Host "$(date) - Password control in progress ..."

    $progressParams = @{
        Activity = "Processing"
        Status = "Checking passwords..."
        PercentComplete = 0
    }
    Write-Progress @progressParams
    $i = 0

    foreach ($user_key in $NTDS) {
        $progressParams.PercentComplete = ($i++ / $total_users) * 100
        Write-Progress @progressParams

        $user = $user_key.split(":")[0]
        $hash = $user_key.split(":")[1]

        if ($hash -eq "31d6cfe0d16ae931b73c59d7e0c089c0" -or [string]::IsNullOrWhiteSpace($hash)) {
            $user | Out-File "$directory_audit\results\Empty_users.txt" -Append
            Write-Host "[*] User's password $user is empty!" -ForegroundColor Yellow
            $empty_count++
            continue
        }

        $prefix = $hash.ToUpper().Substring(0, 5)
        $suffix = $hash.ToUpper().Substring(5)
        $response = Invoke-WebRequest "https://api.pwnedpasswords.com/range/$prefix?mode=ntlm" -UseBasicParsing |
                    Select-Object -ExpandProperty Content

        if ($response -match $suffix) {
            $user | Out-File "$directory_audit\results\Compromised_users.txt" -Append
            Write-Host "[+] User's password $user is compromised!" -ForegroundColor Green
            $compromised_count++
        }
    }

    Write-Host "`n$(date) - Audit Completed!"
    Write-Host "$empty_count empty passwords" -ForegroundColor Yellow
    Write-Host "$compromised_count compromised passwords" -ForegroundColor Green

    Stop-Transcript | Out-Null
    Start-Sleep 60
}

Write-Host "Menu :"
Write-Host "1 - Extract NTDS database only"
Write-Host "2 - Control NTLM hashes from previous extract (Recommended with a random public IP)" -ForegroundColor Yellow
Write-Host "3 - Full audit (Recommended in a lab environment)" -ForegroundColor Yellow
Write-Host "4 - Exit"

$choice = Read-Host "Select an option"

Switch ($choice) {
    "1" { DSInternals; NTDS_copy; Stop-Transcript | Out-Null }
    "2" { DSInternals; Password_Control }
    "3" { DSInternals; NTDS_copy; Password_Control }
    "4" { exit }
    default { Write-Host "Invalid choice. Please choose a valid option." -ForegroundColor Red }
}
