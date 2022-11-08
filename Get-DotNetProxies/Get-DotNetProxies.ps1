<#
    Filename: Get-DotNetProxies.ps1
    Contributors: Kieran Walsh
    Created: 2022-11-08
    Last Updated: 2022-11-08
    Version: 1.00.00
#>

$DotNetInstallationPaths = (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
    Get-ItemProperty -Name 'InstallPath' -ErrorAction 'SilentlyContinue' |
    Where-Object{$_.InstallPath} |
    Sort-Object -Property 'InstallPath' -Unique).InstallPath

if($DotNetInstallationPaths)
{
    $ConfigFiles = (
        Get-ChildItem -File -Filter '*.config' -Force -Path $DotNetInstallationPaths -Recurse -ErrorAction 'SilentlyContinue' |
        Where-Object {$_.Name -match 'Machine.config|Web.config'}
    ).FullName
    if($ConfigFiles)
    {
        $Found = $false
        "Checking configuration in $(($ConfigFiles | Measure-Object).Count) matching files."
        foreach($ConfigFile in $ConfigFiles)
        {
            [xml]$XmlDocument = Get-Content -Path $ConfigFile
            $Proxy = $XmlDocument.configuration.'system.net'.defaultProxy.proxy.proxyaddress
            if($proxy)
            {
                'Proxy settings configured in:'
                "`tPath: '$ConfigFile'"
                "`tProxy: '$Proxy'"
                $Found = $true
            }
        }
        if(-not($Found))
        {
            'No proxy settings found.'
        }
    }
    Else
    {
        'No matching config files found.'
    }
}
Else
{
    'No .NET installations found in the registry.'
}