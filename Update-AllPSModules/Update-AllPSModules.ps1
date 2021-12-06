<#
    .SYNOPSIS
    This script will update all locally installed PowerShell modules to the newest ones if can find online.
    .DESCRIPTION
    The script will search the usual PowerShell module profile paths for all modules and update them to the newest versions available online.

    Updating modules depends on ‘PackageManagement’ and ‘PowerShellGet’, which are updated to the newest versions before upgrading any modules.
    By default, it searches for beta, nightly, preview versions, etc., but you can exclude those with the “-NoPreviews” switch.

    The script presents you with a list of all modules it finds and shows you if a newer version is detected and when that new version was published.

    PowerShell comes with a similar “Update-Module” command, but that does not try to update ‘PackageManagement’ and ‘PowerShellGet’.
    It shows no data while operating, so you are left with an empty screen unless you use the “-verbose” switch, which displays too much information.
    You can use the “-AllowPrerelease”, but only with a named module. This script will install Prerelease versions of all modules if they exist.

    .PARAMETER NoPreviews
    If you want to avoid versions that include 'beta', 'preview', 'nightly', etc.,  and only upgrade to fully released versions of the modules, use this switch.
    .EXAMPLE
    Update-AllPSModules
    This will update all locally installed modules .
    .EXAMPLE
    Update-AllPSModules -NoPreviews
    This will update all locally installed modules but not to versions that include 'beta', 'preview', 'nightly', etc.
    .NOTES
    Filename:       Update-AllPSModules.ps1
    Contributors:   Kieran Walsh
    Created:        2021-01-09
    Last Updated:   2021-12-06
    Version:        1.43.02
#>
[CmdletBinding()]
Param(
    [Parameter()]
    [switch]$NoPreviews
)

if($PSVersionTable.psversion -lt [version]'5.0.0')
{
    Write-Warning -Message "This script only works with PowerShell 5.0 or newer. You are running $($PSVersionTable.PSVersion)"
    break
}
if($ExecutionContext.SessionState.LanguageMode -eq 'ConstrainedLanguage')
{
    Write-Warning 'Constrained Language mode is enabled, so the script cannot continue.'
    continue
}

$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
If(-not(New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList $CurrentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
{
    Write-Host -ForegroundColor 'Red' -Object 'The script is not being run as administrator so cannot continue.'
    Break
}
$StartTime = Get-Date

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$NewSessionRequired = $false
try
{
    $RegisteredRepositories = Get-PSRepository -ErrorAction 'Stop' -WarningAction 'Stop'
}
catch
{
    Write-Warning "Unable to query 'PSGallery' online. The script cannot continue - check your proxy/firewall settings."
    break
}

if($RegisteredRepositories -notmatch 'PSGallery')
{
    try
    {
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted' -ErrorAction 'Stop'
    }
    catch
    {
        'Unable to Set the PSRepository'
        break
    }
}

Write-Host -Object "Checking which version of the 'PackageManagement' module is installed locally" -NoNewline
$PackageManagement = (Get-Module -ListAvailable -Name 'PackageManagement' | Sort-Object Version -Descending)[0]
Write-Host -Object " - found '$(($PackageManagement.version).tostring())'."
if([version]$PackageManagement.Version -lt [version]'1.4.7')
{
    "An updated version is required. Attempting to install 'Nuget'"
    try
    {
        $NugetInstall = Install-PackageProvider -Name 'Nuget' -Force -ErrorAction 'Stop'
        Write-Host -Object "Successfully installed 'Nuget' version '$($NugetInstall.Version)'"
    }
    catch
    {
        if($error[0].exception.message -match 'No match was found for the specified search criteria for the provider ')
        {
            Write-Warning -Message 'Unable to find packages online. Check proxy settings.'
        }
        Else
        {
            Write-Host -Object 'Unknown error.'
        }
        break
    }
    Write-Host -Object "Searching for a newer version of 'PackageManagement'."
    try
    {
        $OnlinePackageManagement = Find-Module -Name 'PackageManagement' -Repository 'PSGallery' -ErrorAction Stop
    }
    catch
    {
        Write-Host -Object "Unable to find 'PackageManagement' online. Does this machine have an internet connection?"
        break
    }
    try
    {
        $OnlinePackageManagement | Install-Module -Force -SkipPublisherCheck -ErrorAction Stop
        Write-Host -Object "Successfully installed 'PackageManagement' version '$($OnlinePackageManagement.Version)'"
    }
    catch
    {
        Write-Host -Object "Failed to install 'PackageManagement'."
        break
    }
    Write-Host -Object "You need to close PowerShell and re-open it to use the new 'PackageManagement' module."
    $NewSessionRequired = $true
}

Write-Host -Object "Checking which version of the 'PowerShellGet' module is installed locally" -NoNewline
$PowershellGet = (Get-Module -ListAvailable -Name 'PowerShellGet' | Sort-Object Version -Descending)[0]
Write-Host -Object " - found '$(($PowershellGet.version).tostring())'."

if([version]$PowershellGet.Version -lt [version]'1.6.0')
{
    $OnlinePSGet = Find-Module -Name 'PowershellGet' -Repository 'PSGallery'
    Write-Host -Object "Version '$($OnlinePSGet.version)' found online, will attempt to update."
    try
    {
        $OnlinePSGet | Install-Module -Force -SkipPublisherCheck -ErrorAction Stop
        Write-Host -Object "Successfully installed 'PowerShellGet' version '$($OnlinePSGet.Version)'. Close PowerShell and re-open it to use the new module."
        $NewSessionRequired = $true
    }
    catch
    {
        Write-Host -Object "Unable to install to 'C:\Program Files\WindowsPowerShell\Modules' so will try the Current User module path instead."
        try
        {
            $OnlinePSGet | Install-Module -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
            Write-Host -Object "Successfully installed 'PowerShellGet' version '$($OnlinePSGet.Version)'. Close PowerShell and re-open it to use the new module."
            $NewSessionRequired = $true
        }
        catch
        {
            Write-Warning 'Failed to install the latest version of PowerShellGet. This will mean you may not be able to install preview, or beta versions of the modules.'
            break
        }
    }
}

if($NewSessionRequired)
{
    break
}
$Failed = @()
Write-Host -Object 'Searching for all locally installed modules' -NoNewline

$InstalledModules = Get-InstalledModule |
Where-Object -FilterScript {
    ($_.name -notmatch 'PackageManagement|PowerShellGet|Az\.|AzureRM\.|Azure\.|PSReadline')
} |
Sort-Object -Property 'Name'

if($InstalledModules)
{
    Write-Host -Object " - $(($InstalledModules | Measure-Object).count) modules found."
    Write-Host -Object 'Checking for newer versions online and trying to update them.'
    $MaxNameWidth = (($InstalledModules).'Name' |
        Sort-Object -Property 'Length' -Descending |
        Select-Object -First 1).length + 3

    $MaxVersionWidth = (($InstalledModules).'Version' |
        Sort-Object -Property 'Length' -Descending |
        Select-Object -First 1).length + 3

    foreach($InstalledModule in $InstalledModules)
    {
        Write-Host -Object ("{0,-$MaxNameWidth}" -f $InstalledModule.Name ) -NoNewline
        if($NoPreviews)
        {
            try
            {
                $Module = Get-InstalledModule -Name $InstalledModule.Name -AllVersions |
                Sort-Object -Property {
                    [version](($_.Version -split '-')[0])
                } -Descending |
                Select-Object -First 1
                $LatestAvailable = Find-Module -Name $InstalledModule.Name -ErrorAction Stop
            }
            catch
            {
                $Failed += $InstalledModule
                continue
            }
        }
        Else
        {
            try
            {
                $Module = Get-InstalledModule -Name $InstalledModule.Name -AllowPrerelease -AllVersions |
                Sort-Object -Property {
                    [version](($_.Version -split '-')[0])
                } -Descending |
                Select-Object -First 1
                $LatestAvailable = Find-Module -Name $InstalledModule.Name -AllowPrerelease -ErrorAction Stop
            }
            catch
            {
                $Failed += $InstalledModule
                continue
            }
        }
        Write-Host -Object ("{0,-$MaxVersionWidth}" -f $Module.Version) -NoNewline
        if(([version](($Module.Version -replace '[a-z]*', '').Replace('-', '.') -replace '\.$', '')) -ge ([version](($LatestAvailable.Version -replace '[a-z]*', '').Replace('-', '.') -replace '\.$', '')))
        {
            Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
        }
        else
        {
            $AllUsersFailed = $false
            $Gap = (20 - (($LatestAvailable.version).length))
            Write-Host -Object ("Online version found: '{0}' - attempting to update. {1,$Gap}" -f "$($LatestAvailable.version)' - Published '$(Get-Date($LatestAvailable.PublishedDate) -Format 'yyyy-MM-dd')", ' ') -ForegroundColor 'Yellow' -NoNewline
            If($NoPreviews)
            {
                try
                {
                    Update-Module -AcceptLicense -Force -Name $Module.Name -Scope 'AllUsers' -ErrorAction 'Stop'
                    Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
                }
                catch
                {
                    $AllUsersFailed = $true
                }
            }
            Else
            {
                try
                {
                    Update-Module -AcceptLicense -AllowPrerelease -RequiredVersion $LatestAvailable.version -Force -Name $Module.Name -Scope 'AllUsers' -ErrorAction 'Stop'
                    Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
                }
                catch
                {
                    $AllUsersFailed = $true
                }
            }
            if($AllUsersFailed)
            {
                try
                {
                    Update-Module -AcceptLicense -AllowPrerelease -RequiredVersion $LatestAvailable.version -Force -Name $Module.Name -Scope 'CurrentUser' -ErrorAction 'Stop'
                    Write-Host -Object $([char]0x2714) -ForegroundColor 'Green' -NoNewline
                    Write-Host -Object " ('Current User' scope only)" -ForegroundColor 'Yellow'
                }
                catch
                {
                    Write-Host -Object ([char]0x2718) -ForegroundColor 'Red' -NoNewline
                    Write-Host -Object (' Update not possible, will uninstall and try a new install. ') -ForegroundColor 'Yellow' -NoNewline
                    try
                    {
                        Uninstall-Module -Name $Module.Name -AllowPrerelease -AllVersions -Force -ErrorAction 'Stop'
                        try
                        {
                            Install-Module -Name $Module.Name -RequiredVersion $LatestAvailable.version -AcceptLicense -AllowClobber -AllowPrerelease -Force -Scope 'AllUsers' -SkipPublisherCheck -ErrorAction 'Stop'
                            Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
                        }
                        catch
                        {
                            try
                            {
                                Install-Module -Name $Module.Name -RequiredVersion $LatestAvailable.version -AcceptLicense -AllowClobber -AllowPrerelease -Force -Scope 'CurrentUser' -SkipPublisherCheck -ErrorAction 'Stop'
                                Write-Host -Object $([char]0x2714) -ForegroundColor 'Green' -NoNewline
                                Write-Host -Object " ('Current User' scope only)" -ForegroundColor 'Yellow'
                            }
                            catch
                            {
                                Write-Host -Object ([char]0x2718) -ForegroundColor 'Red'
                            }
                        }
                    }
                    catch
                    {
                        Write-Host -Object ([char]0x2718) -ForegroundColor 'Red'
                    }
                }
            }
        }
    }
}
Else
{
    '. None found.'
}

$OnlinePSGet = Find-Module -Name 'PowershellGet' -AllowPrerelease -Repository 'PSGallery' -ErrorAction Stop
if(([version](($PowershellGet.Version -split ('-'))[0])) -lt ([version](($OnlinePSGet.Version -split ('-'))[0])))
{
    Write-Host -Object "A newer version of 'PowerShellGet' is available online, will attempt to update."
    try
    {
        $OnlinePSGet | Install-Module -Force -SkipPublisherCheck -ErrorAction Stop
        Write-Host -Object "Successfully installed 'PowerShellGet' version '$($OnlinePSGet.Version)'. Close PowerShell and re-open it to use the new module."
        $NewSessionRequired = $true
    }
    catch
    {
        Write-Host -Object "Unable to install to 'C:\Program Files\WindowsPowerShell\Modules' so will try the Current User module path instead."
        try
        {
            $OnlinePSGet | Install-Module -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
            Write-Host -Object "Successfully installed 'PowerShellGet' version '$($OnlinePSGet.Version)'. Close PowerShell and re-open it to use the new module."
            $NewSessionRequired = $true
        }
        catch
        {
            Write-Warning 'Failed to install the latest version of PowerShellGet. This will mean you may not be able to install preview, or beta versions of the modules.'
            break
        }
    }
}

if($Failed)
{
    'Unable to find these modules:'
    $Failed
}
$EndTime = Get-Date
$TimeTaken = ''
$TakenSpan = New-TimeSpan -Start $StartTime -End $EndTime
if($TakenSpan.Hours)
{
    $TimeTaken += "$($TakenSpan.Hours) hours, $($TakenSpan.Minutes) minutes, "
}
Elseif($TakenSpan.Minutes)
{
    $TimeTaken += "$($TakenSpan.Minutes) minutes, "
}
$TimeTaken += "$($TakenSpan.Seconds) seconds"

"The script took $TimeTaken to complete."