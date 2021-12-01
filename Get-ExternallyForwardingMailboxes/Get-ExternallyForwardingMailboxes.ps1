<#
    .SYNOPSIS
    Lists all Office 365 mailboxes which send email to external addresses.
    .DESCRIPTION
    Lists all Office 365 mailboxes which send email to external addresses.
    All data is saved to a the CSV file listed in the cmdlet variable. If the variable is not entered, the CSV will be saved to the Windows Temp folder by default.
    .PARAMETER CSVFile
    The full path to where you want to save the CSV.
    .PARAMETER NoOutlook
    Use this if you don't care about end user Outlook rules and only wish to list Office 365 rules.
    .PARAMETER NoOffice365
    This parameter will list all Outlook rules, but not Office 365 configurations.
    .PARAMETER EmailAddresses
    If you don't want to query all mailboxes in Office 365, use this parameter to specify a list of email addresses.
    .EXAMPLE
    Get-ExternallyForwardingMailboxes
    This will query all mailboxes and save the results to the Windows Temp folder.
    .EXAMPLE
    Get-ExternallyForwardingMailboxes -CSVFile C:\Temp\ExternallyForwardingMailboxes.csv
    This script will query all mailboxes and save the results to the file C:\Temp\ExternallyForwardingMailboxes.csv
    .EXAMPLE
    Get-ExternallyForwardingMailboxes -NoOutlook
    Will list Office 365 forwarding settings, but not Outlook rules.
    .Example
    Get-ExternallyForwardingMailboxes -NoOffice365
    Will list rules in Outlook but not Office 365.
    .Example
    Get-ExternallyForwardingMailboxes -EmailAddresses 'Anna@mysite.com', 'Zahra@mysite.com'
    Will query only the mailboxes with the specified email addresses.
    .Notes
    Filename: Get-ExternallyForwardingMailboxes.ps1
    Contributors: Kieran Walsh
    Created: 2021-11-26
    Last Updated: 2021-12-01
    Version: 0.03.05
#>

[CmdletBinding()]
Param(
    [Parameter()]
    [string]$CSVFile = "$env:windir\temp\Office 365 sending externally.csv",
    [switch]$NoOutlook,
    [switch]$NoOffice365,
    [string[]]$EmailAddresses = ''
)

try
{
    $null = Get-MsolDomain -ErrorAction Stop
}
catch [System.Management.Automation.CommandNotFoundException]
{
    Write-Warning -Message 'The MSOnline module is not installed on this machine. You can find full details at this URL:'
    Write-Warning -Message 'https://docs.microsoft.com/en-us/microsoft-365/enterprise/connect-to-microsoft-365-powershell?view=o365-worldwide'
    Write-Warning 'Please install those before running this script again.'
    break
}

$AcceptedDomains = (Get-AcceptedDomain).DomainName
if(-not($AcceptedDomains))
{
    Write-Host -Object 'You are not connected to Office 365. Would you like to connect now? (Y/N)'
    $Answer = Read-Host
    if($Answer.ToUpper() -ne 'Y')
    {
        Connect-MsolService -ErrorAction Stop
        Connect-ExchangeOnline -ErrorAction Stop
    }
    Else
    {
        Write-Warning 'Unble to connect to Office 365.'
        break
    }
    $AcceptedDomains = (Get-AcceptedDomain).DomainName
}

if(-not($AcceptedDomains))
{
    'You are not connected to Office 365. Connect and try again.'
    break
}
$Mailboxes = @()
$StartTime = Get-Date
if($EmailAddresses)
{
    foreach($EmailAddress in $EmailAddresses)
    {
        if(-not($EmailAddress -as [System.Net.Mail.MailAddress]))
        {
            Write-Warning -Message "The inputted value '$EmailAddress' is not a valid email address so will be skipped."
            continue
        }
        try
        {
            $Mailboxes += Get-Mailbox -Identity $EmailAddress -ErrorAction stop | Select-Object AccountDisabled, DisplayName, ForwardingAddress, ForwardingSmtpAddress, IsDirSynced, IsMailboxEnabled, Name, PrimarySmtpAddress, WhenChanged, WhenMailboxCreated | Sort-Object Name

        }
        catch
        {
            Write-Warning -Message "Could not find mailbox '$EmailAddress'."
        }
    }
}
Else
{

    Write-Host -Object 'Querying Office 365 for all mailboxes. This may take some time.'
    $Mailboxes = Get-Mailbox -ResultSize Unlimited | Select-Object AccountDisabled, DisplayName, ForwardingAddress, ForwardingSmtpAddress, IsDirSynced, IsMailboxEnabled, Name, PrimarySmtpAddress, WhenChanged, WhenMailboxCreated | Sort-Object Name
}
$Total = ($Mailboxes | Measure-Object).count
if($Total -lt 1)
{
    'There are no mailboxes to check.'
    break
}
Write-Host -Object "There are $Total mailboxes to check."
$Loop = 0

$Output = foreach ($Mailbox In $Mailboxes)
{
    $Loop++
    Write-Host -Object ('{0,4} of {1,-5} {2}' -f $Loop, $Total, $Mailbox.PrimarySmtpAddress)
    $AccountType = switch ($Mailbox.IsDirSynced)
    {
        'True'
        {
            'Active Directory'
        }
        'False'
        {
            'Cloud'
        }
    }
    $AccountEnabled = switch ($Mailbox.AccountDisabled)
    {

        'True'
        {
            'FALSE'
        }
        'False'
        {
            'TRUE'
        }
    }

    if(-not($NoOutlook))
    {
        $ForwardingRules = Get-InboxRule -Mailbox $Mailbox.PrimarySmtpAddress | Where-Object {($_.ForwardAsAttachmentTo -ne $null) -or ($_.ForwardTo -ne $null) -or ($_.RedirectTo -ne $null)}
        foreach ($Rule in $ForwardingRules)
        {
            if($Rule.ForwardTo -or $Rule.ForwardAsAttachmentTo -or $Rule.RedirectTo)
            {
                $ForwardingAddresses = @(
                    $Rule.ForwardTo
                    $Rule.ForwardAsAttachmentTo
                    $Rule.RedirectTo
                )
                foreach($Email in $ForwardingAddresses)
                {
                    $RuleType = 'Outlook'
                    $RecipientAddress = (($Email -split '\[')[1] -split ']')[0] -replace 'smtp:', ''
                    $EmailDomain = ($RecipientAddress -split '@')[1]
                    if(($EmailDomain) -and ($AcceptedDomains -notcontains $EmailDomain))
                    {
                        if($Rule.ForwardTo)
                        {
                            $String = 'forwards to'
                        }
                        if($Rule.ForwardAsAttachmentTo)
                        {
                            $String = 'forwards as attachment to'
                        }
                        if($Rule.RedirectTo)
                        {
                            $String = 'redirects to'
                        }
                        Write-Host "`tMailbox '$($Mailbox.PrimarySmtpAddress)' - Outlook Rule Name '$($Rule.Name)' with a Rule Identity of '$($Rule.Identity)' $String '$RecipientAddress'."
                        [PSCustomObject]@{
                            'Account'         = $Mailbox.DisplayName
                            'Account Type'    = $AccountType
                            'Account Enabled' = $AccountEnabled
                            'Account Created' = Get-Date($Mailbox.WhenMailboxCreated) -Format 'yyyy-MM-dd'
                            'Account Changed' = Get-Date($Mailbox.WhenChanged) -Format 'yyyy-MM-dd'
                            'Mailbox Enabled' = $Mailbox.IsMailboxEnabled
                            'Rule Type'       = $RuleType
                            'Rule Name'       = $Rule.Name
                            'Rule Identity'   = $Rule.Identity
                            'Mailbox'         = $Mailbox.PrimarySmtpAddress
                            'Action'          = $String
                            'Email Address'   = $RecipientAddress
                        }
                    }
                }
            }
        }
    }
    if(-not($NoOffice365))
    {
        $O365Rules = $Mailbox | Where-Object {($_.ForwardingAddress -ne $null) -or ($_.ForwardingSmtpAddress -ne $null)}
        foreach($O365Rule in $O365Rules)
        {
            $ForwardingAddresses = @(
                $O365Rule.ForwardingAddress
                $O365Rule.ForwardingSmtpAddress
            )
            foreach($Email in $ForwardingAddresses)
            {
                $RuleType = 'Office 365'
                $RecipientAddress = $Email -replace 'smtp:', ''
                $EmailDomain = ($RecipientAddress -split '@')[1]
                if(($EmailDomain) -and ($AcceptedDomains -notcontains $EmailDomain))
                {
                    if($O365Rule.ForwardingAddress)
                    {
                        $String = 'forwards to'
                    }
                    if($O365Rule.ForwardingSmtpAddress)
                    {
                        $String = 'forwards to'
                    }

                    Write-Host "`tMailbox '$($Mailbox.PrimarySmtpAddress)' - has an Office 365 configuration which $String email to '$RecipientAddress'."
                    [PSCustomObject]@{
                        'Account'         = $Mailbox.DisplayName
                        'Account Type'    = $AccountType
                        'Account Enabled' = $AccountEnabled
                        'Account Created' = Get-Date($Mailbox.WhenMailboxCreated) -Format 'yyyy-MM-dd'
                        'Account Changed' = Get-Date($Mailbox.WhenChanged) -Format 'yyyy-MM-dd'
                        'Mailbox Enabled' = $Mailbox.IsMailboxEnabled
                        'Rule Type'       = $RuleType
                        'Rule Name'       = 'N/A'
                        'Rule Identity'   = 'N/A'
                        'Mailbox'         = $Mailbox.PrimarySmtpAddress
                        'Action'          = $String
                        'Email Address'   = $RecipientAddress
                    }
                }
            }
        }
    }
}

try
{
    $Output | ConvertTo-Csv -NoTypeInformation |  Out-File -FilePath $CSVFile -Encoding UTF8 -ErrorAction stop
    Write-Host ' '
    Write-Host "All data has been saved to '$CSVFile'."
}
Catch
{
    "The CSV file '$CSVFile' could not be created. Please ensure that the path exists. Cannot write to a file that is currently open, so please close it if so."
    Write-Host -Object "When you've corrected problems I can try to save again. Should I try to save again now? (Y/N)"
    $Answer = Read-Host
    if($Answer.ToUpper() -ne 'Y')
    {
        try
        {
            $Output | ConvertTo-Csv -NoTypeInformation |  Out-File -FilePath $CSVFile -Encoding UTF8 -ErrorAction stop
        }
        catch
        {
            Write-Warning  "Failed to save to path '$CSVFile'."
        }
    }
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