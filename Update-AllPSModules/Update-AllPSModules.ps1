<#
    Filename: Update-AllPSModules.ps1
    Contributors: Kieran Walsh
    Created: 2021-01-09
    Last Updated: 2021-10-25
    Version: 1.36.00
#>

if($PSVersionTable.psversion -lt [version]'5.0.0')
{
    Write-Warning -Message "This script only works with PowerShell 5.0 or newer. You are running $($PSVersionTable.PSVersion)"
    break
}

$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
If(-not(New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $CurrentUser).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
{
    Write-Host -ForegroundColor Red -Object 'The script is not being run as administrator so cannot continue.'
    Break
}
$StartTime = Get-Date

[Net.ServicePointManager]::SecurityProtocol = 'tls12'
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
$NewSessionRequired = $false
$RegisteredRepositories = Get-PSRepository -Name 'PSGallery'
if($RegisteredRepositories -notmatch 'PSGallery')
{
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
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
    $_.name -notmatch 'PackageManagement|PowerShellGet|Az\.|AzureRM\.|Azure\.'
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
        $Module = Get-InstalledModule -Name $InstalledModule.Name -AllowPrerelease -AllVersions |
        Sort-Object -Property {
            [version](($_.Version -split '-')[0])
        } -Descending |
        Select-Object -First 1

        Write-Host -Object ("{0,-$MaxNameWidth}{1,-$MaxVersionWidth}" -f $Module.Name, $Module.Version) -NoNewline -ForegroundColor 'White'

        try
        {
            $LatestAvailable = Find-Module -Name $InstalledModule.Name -ErrorAction Stop
        }
        catch
        {
            $Failed += $InstalledModule
            continue
        }

        if (([version](($Module.Version -split ('-'))[0])) -ge ([version](($LatestAvailable.Version -split ('-'))[0])))
        {
            Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
        }
        else
        {
            $Gap = (20 - (($LatestAvailable.version).length))
            Write-Host -Object ("Online version found: '{0}' - attempting to update. {1,$Gap}" -f $($LatestAvailable.version), ' ') -ForegroundColor 'Yellow' -NoNewline
            try
            {
                Update-Module -AcceptLicense -AllowPrerelease -Force -Name $Module.Name -Scope 'AllUsers' -ErrorAction 'Stop'
                Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
            }
            catch
            {
                try
                {
                    Update-Module -AcceptLicense -AllowPrerelease -Force -Name $Module.Name -Scope 'CurrentUser' -ErrorAction 'Stop'
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
                            Install-Module -Name $Module.Name -AcceptLicense -AllowClobber -AllowPrerelease -Force -Scope 'AllUsers' -SkipPublisherCheck -ErrorAction 'Stop'
                            Write-Host -Object $([char]0x2714) -ForegroundColor 'Green'
                        }
                        catch
                        {
                            try
                            {
                                Install-Module -Name $Module.Name -AcceptLicense -AllowClobber -AllowPrerelease -Force -Scope 'CurrentUser' -SkipPublisherCheck -ErrorAction 'Stop'
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