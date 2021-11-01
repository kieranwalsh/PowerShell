<#
    Filename: Get-NetworkLogons.ps1
    Contributors: Kieran Walsh
    Created: 2020-11-15
    Last Updated: 2021-11-01
    Version: 2.07.00
#>

[CmdletBinding()]
Param(
    [Parameter(Position = 1)]
    [Alias('Name')]
    [string]$ComputerName = '',
    [ValidateSet('Workstation', 'Server')]
    [string]$Type = 'Workstation',
    [switch]$HideOff,
    [switch]$AvailableOnly,
    [switch]$RemoteFirstAvailable,
    [Switch]$Restart
)

function Start-RemoteServices
{
    $Services = 'WinRM', 'RemoteRegistry', 'Winmgmt'
    Foreach($Service in $Services)
    {
        $Service
        try
        {
            Get-Service -ComputerName $Computer -Name $Service -ErrorAction Stop | Where-Object -FilterScript {
                $_.Status -ne 'Running'
            }
            Set-Service -Name $Service -ComputerName $Computer -StartupType Automatic -Status Running
        }
        catch
        {
            $False
            Return
        }
        $true
    }
}

If($PSVersionTable.PSVersion.Major -lt 3)
{
    'You must be running PowerShell version 3 or higher to run this script.'
    "This machine is on PowerShell $($PSVersionTable.PSVersion.Major)."
    break
}

$OnCount = 0
$FreeCount = 0
$Finish = $False
$Date = (Get-Date).AddDays(-20)
$CommandPath = $MyInvocation.MyCommand.Path
$ScriptVersion = (Get-Content -Path $CommandPath | Select-String 'Version:')[0] -replace 'Version:', '' -replace ' ', ''
"Starting script version '$ScriptVersion'."
# Make sure AD DS Snap-Ins, Command-Line Tools and Active Directory module for Windows PowerShell are installed
$prerequisites = ('RSAT-ADDS-Tools', 'RSAT-AD-PowerShell', 'GPMC')
Import-Module -Name servermanager
foreach($prerequisite in $prerequisites)
{
    If (-not(Get-WindowsFeature -Name $prerequisite).Installed)
    {
        Install-WindowsFeature -Name $prerequisite
    }
}

# Find requested AD computers.
$Computers = Get-ADComputer -Properties OperatingSystem, LastLogonTimeStamp -Filter {
    (OperatingSystem -like '*Windows*') -and (LastLogonTimeStamp -gt $Date)
}
If ($Type -eq 'Workstation')
{
    $Computers = ($Computers | Where-Object -FilterScript {
            ($_.OperatingSystem -notmatch 'Server') -and ($_.name -match $ComputerName)
        }).Name | Sort-Object
}
ElseIf ($Type -eq 'Server')
{
    $Computers = ($Computers | Where-Object -FilterScript {
            ($_.OperatingSystem -match 'Server') -and ($_.name -match $ComputerName)
        }).Name | Sort-Object
}
Else
{
    $Computers = ($Computers | Where-Object -FilterScript {
            $_.name -match $ComputerName
        }).Name | Sort-Object
}

"There are $($Computers.count) computers to check."
$MaxLength = ($Computers |
    Sort-Object -Property length -Descending |
    Select-Object -Property length -First 1).length + 2

if($AvailableOnly)
{
    $HideOff = $true
}

Foreach ($Computer in $Computers)
{
    if($Finish)
    {
        break
    }

    If(Test-Connection -ComputerName $Computer -Count 1 -Quiet)
    {
        $OnCount++
    }
    Else
    {
        if(-not ($HideOff))
        {
            Write-Host -ForegroundColor 'Red' -Object $("{0,-$MaxLength}{1}" -f $Computer, 'Uncontactable')
        }
        continue
    }

    $Sessions = (C:\Windows\System32\quser.exe /server:$Computer 2>&1)

    If(-not($Sessions))
    {
        $FreeCount++
        $User = 'Unused'
        $Fontcol = 'Yellow'
        Write-Host -ForegroundColor $Fontcol -Object $("{0,-$MaxLength}{1}" -f $Computer, $User)
        if($RemoteFirstAvailable)
        {
            $Finish = $true
            mstsc.exe /f /v $Computer
        }
        if($Restart)
        {
            Restart-Computer -ComputerName $Computer
        }
        continue
    }
    if($AvailableOnly)
    {
        continue
    }

    if($Sessions -match 'Access is denied.')
    {
        $User = 'Cannot query users - access denied.'
        $Fontcol = 'Yellow'
        Write-Host -ForegroundColor $Fontcol -Object $("{0,-$MaxLength}{1}" -f $Computer, $User)
        continue
    }
    if($Sessions -match '0x000006BA')
    {
        $RemoteIP = (Test-NetConnection -ComputerName $Computer).RemoteAddress.IPAddressToString
        $RemoteComputer = (Resolve-DnsName -Name $RemoteIP).NameHost
        if(-not($Computer -match $RemoteComputer))
        {
            Write-Host "DNS duplicate issues. The IP of computer '$Computer' resolves to the device '$(($RemoteComputer -split '\.')[0])'. Check DNS scavenging." -ForegroundColor Red
            continue
        }
        Else
        {
            Invoke-Command -ComputerName $Computer -Command { Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name AllowRemoteRPC  -Value 0x1 -Force }
            $Sessions = (C:\Windows\System32\quser.exe /server:$Computer 2>&1)
            if($Sessions -notmatch 'SESSIONNAME')
            {
                $User = 'Cannot query users.'
                $Fontcol = 'Yellow'
                Write-Host -ForegroundColor $Fontcol -Object $("{0,-$MaxLength}{1}" -f $Computer, $User)
                continue
            }
        }
    }

    $Sessions = $Sessions | Select-Object -Skip 1
    $SessionUsers = foreach($Session in $Sessions)
    {
        If($Session.State -eq 'Active')
        {
            $Days = 0
            $Hours = 0
            $Mins = 0
        }
        Else
        {
            $IdleTime = $Session.Substring(54, 11).trim()
            If($IdleTime -match '\+')
            {
                $Days = ($IdleTime -split '\+')[0]
            }
            Else
            {
                $Days = 0
            }

            If($IdleTime -match ':')
            {
                $Hours = ($IdleTime -split {
                        $_ -eq '+' -or $_ -eq ':'
                    })[1]
            }
            Else
            {
                $Hours = 0
            }
            If($IdleTime -match 'none')
            {
                $Mins = 0
            }
            Else
            {
                $Mins = ($IdleTime -split {
                        $_ -eq '+' -or $_ -eq ':'
                    })[-1]
            }
        }

        [PSCustomObject]@{
            'Computer'    = $Computer
            'Username'    = $Session.Substring(1, 22).trim()
            'SessionName' = $Session.Substring(23, 19).trim()
            'Id'          = $Session.Substring(42, 4).trim()
            'State'       = $Session.Substring(46, 8).trim()
            'IdleDays'    = $Days
            'IdleHours'   = $Hours
            'IdleMins'    = $Mins
            'LogonTime'   = (Get-Date -Date $Session.Substring(65, ($Session.length - 65)).trim() -Format 'yyyy-MM-dd HH:mm')
        }
    }
    $SessionUsers = $SessionUsers | Sort-Object -Property State

    foreach($SessionUser in $SessionUsers)
    {
        if($SessionUser.State -eq 'Active')
        {
            if(($SessionUser.IdleDays -eq 0) -and ($SessionUser.IdleHours -eq 0) -and ($SessionUser.IdleMins -eq 0))
            {
                $Fontcol = 'Green'
                Write-Host -ForegroundColor $Fontcol -Object $("{0,-$MaxLength}{1,-22}{2,-20}Logon: {3,-18}" -f $Computer, 'Connected - Active', $SessionUser.Username, $SessionUser.LogonTime)
                continue
            }
            Else
            {
                $Fontcol = 'Green'
                Write-Host -ForegroundColor $Fontcol -Object $("{0,-$MaxLength}{1,-22}{2,-20}Logon: {3,-18}Idle time - Days: {4}, Hours: {5}, Minutes: {6}" -f $Computer, 'Connected - Idle', $SessionUser.Username, $SessionUser.LogonTime, $SessionUser.IdleDays, $SessionUser.IdleHours, $SessionUser.IdleMins)
                continue
            }
        }
        $Fontcol = 'White'
        Write-Host -ForegroundColor $Fontcol -Object $("{0,-$MaxLength}{1,-22}{2,-20}Logon: {3,-18}Idle time - Days: {4}, Hours: {5}, Minutes: {6}" -f ' ', 'Disconnected', $SessionUser.Username, $SessionUser.LogonTime, $SessionUser.IdleDays, $SessionUser.IdleHours, $SessionUser.IdleMins)
    }
}
