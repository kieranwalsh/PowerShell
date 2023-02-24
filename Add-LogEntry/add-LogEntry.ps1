function add-LogEntry
{
    <#
    .SYNOPSIS
    Add-LogEntry sends output to the host and a log file.

    .DESCRIPTION
    Add-LogEntry sends output to the host and a log file.
    Output sent to the log file includes time entries. Those are not generally needed on the host and may take up too much room.
    You can pass on directions to indent output or indicate that it was a Success, Warning, or Failure. Everything else is marked as Info.
    Info data is sent to the screen in the default white font, but everything else uses appropriate colours

    .PARAMETER Logfile
    The full path to where you want to save the log. There's no need to specify this every time if you enter this in your main script:
    $PSDefaultParameterValues = @{'add-LogEntry:LogFile' = 'C:\scripts\sample output.log'}

    .PARAMETER Output
    The data you wish to send to the host and logfile.

    .PARAMETER ClearLog
    Overwrites the current logfile with this entry only. Generally would be used at the start of the script.

    .PARAMETER BlankLine
    Still outputs the timespamp, but does not include any data. Useful for separating sections of the log.

    .PARAMETER IndentSize
    The number of spaces that text is indented by. The default is 4.

    .PARAMETER Indent
    Data that you want to indent by IndentSize spaces. Can help readability in some situations.

    .PARAMETER DoubleIndent
    Data that you want to indent by 2 X IndentSize spaces.

    .PARAMETER TripleIndent
    Data that you want to indent by 3 X IndentSize spaces.

    .PARAMETER IsError
    Marks the entry as [Error] in the logfile and colours the data in RED in the host.

    .PARAMETER IsPrompt
    Marks the entry as [Prompt] in the logfile and colours the data in YELLOW in the host.

    .PARAMETER IsSuccess
    Marks the entry as [Success] in the logfile and colours the data in GREEN in the host.

    .PARAMETER IsWarning
    Marks the entry as [Warning] in the logfile and colours the data in YELLOW in the host.

    .EXAMPLE
    add-LogEntry -Output "Starting script"
    Host:
        Starting script

    Logfile:
        2021-05-03 10:01:43   INFO      Starting script

    .EXAMPLE
    add-LogEntry -Output "Computer '$computer' is uncontactable" -IsWarning
    Host:
        Computer 'PC01' is uncontactable

    Logfile:
        2021-05-03 14:03:39   [WARNING] Computer 'PC01' is uncontactable


    .EXAMPLE
    add-LogEntry -Output "Querying computer '$computer'"
    add-LogEntry -Output "Processor: $CPU" -indent
    add-LogEntry -Output "Memory: $RAM" -indent

    Host:
        Querying computer 'PC01'
        Processor: Core i5-11600K
        Memory: 16 GB

    Logfile:
        2021-05-03 14:07:58   INFO      Querying computer 'PC01'
        2021-05-03 14:08:00   INFO          Processor: Core i5-11600K
        2021-05-03 14:08:01   INFO          Memory: 16 GB

    .EXAMPLE
    add-LogEntry -Output 'Checking if all required Windows Features are installed:'
    foreach($RequiredWindowsFeature in $RequiredWindowsFeatures)
    {
        add-LogEntry -Output $RequiredWindowsFeature -Indent
        If (-not(Get-WindowsFeature -Name $RequiredWindowsFeature).Installed)
        {
            add-LogEntry -Output 'Feature is missing, will attempt to install now.' -DoubleIndent
            try
            {
                $null = Add-WindowsFeature -Name $RequiredWindowsFeature -ErrorAction Stop
                add-LogEntry -Output 'Success' -IsSuccess -DoubleIndent
            }
            catch
            {
                add-LogEntry -Output "Failed to install '$RequiredWindowsFeature'" -DoubleIndent -IsError
            }
        }
    }

    Host:
        Checking if all required Windows Features are installed:
        RSAT-ADDS-Tools
        Feature is missing, will attempt to install now.
        Success

    Logfile:
        2021-06-08 15:45:56   INFO       Checking if all required Windows Features are installed:
        2021-06-08 15:45:57   INFO           RSAT-ADDS-Tools
        2021-06-08 15:45:57   INFO               Feature is missing, will attempt to install now.
        2021-06-08 15:46:39   [SUCCESS]          Success

    .NOTES
        Filename: add-LogEntry.ps1
        Contributors: Kieran Walsh
        Created: 2018-01-12
        Last Updated: 2023-02-21
        Version: 0.08.01
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [Alias('Message')]
        [string]$Output,
        [int]$IndentSize = 4,
        [string]$LogFile = 'C:\Windows\Temp\file.log',
        [switch]$BlankLine,
        [switch]$ClearLog,
        [switch]$DoubleIndent,
        [switch]$Indent,
        [switch]$IsError,
        [switch]$IsPrompt,
        [switch]$IsSuccess,
        [switch]$IsWarning,
        [switch]$TripleIndent
    )
    $ForegroundColor = 'White'
    if($DoubleIndent)
    {
        $Space = ($IndentSize * 2) + 1
    }
    Elseif($Indent)
    {
        $Space = $IndentSize + 1
    }
    Elseif($TripleIndent)
    {
        $Space = ($IndentSize * 3) + 1
    }
    Else
    {
        $Space = 1
    }
    $Type = 'INFO'
    if($IsError)
    {
        $Type = '[ERROR]'
        $ForegroundColor = 'Red'
    }
    if($IsPrompt)
    {
        $Type = '[PROMPT]'
        $ForegroundColor = 'Yellow'
    }
    if($IsSuccess)
    {
        $Type = '[SUCCESS]'
        $ForegroundColor = 'Green'
    }
    if($IsWarning)
    {
        $Type = '[WARNING]'
        $ForegroundColor = 'Yellow'
    }
    Write-Host -Object $Output -ForegroundColor $ForegroundColor
    if($ClearLog)
    {
        "{0,-22}{1,-11}{2,-$Space}{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Type, ' ', $Output | Out-File -FilePath $LogFile -Encoding 'utf8'
    }
    Else
    {
        "{0,-22}{1,-11}{2,-$Space}{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Type, ' ', $Output | Out-File -FilePath $LogFile -Encoding 'utf8' -Append
    }
}

function stop-Script
{
    <#
    functionName: stop-Script
    Contributors: Kieran Walsh
    Created: 2019-01-22
    Last Updated: 2023-02-21
    Version: 1.02.00
#>
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [string]$ExitCode = 128,
        [string]$ErrorMessage = $null
    )
    $EndTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $TimeTaken = ''
    $TakenSpan = New-TimeSpan -Start $StartTime -End $EndTime
    if($TakenSpan.Days)
    {
        $TimeTaken += "$($TakenSpan.Days) days, $($TakenSpan.Hours) hours, $($TakenSpan.Minutes) minutes, $($TakenSpan.Seconds) seconds"
    }
    elseif($TakenSpan.Hours)
    {
        $TimeTaken += "$($TakenSpan.Hours) hours, $($TakenSpan.Minutes) minutes, $($TakenSpan.Seconds) seconds"
    }
    elseif($TakenSpan.Minutes)
    {
        $TimeTaken += "$($TakenSpan.Minutes) minutes, $($TakenSpan.Seconds) seconds"
    }
    elseif($TakenSpan.Seconds)
    {
        $TimeTaken += "$($TakenSpan.Seconds) seconds"
    }
    else
    {
        $TimeTaken = 'under a second'
    }

    if($ExitCode -ne 0)
    {
        add-LogEntry -Message 'Last error data:'
        if($ErrorMessage)
        {
            add-LogEntry -Message "'$ErrorMessage'" -Indent -IsError
        }
        add-LogEntry -Message "Error message: '$(($error[0].exception.message).Trim())'." -Indent
        add-LogEntry -Message "Error exception: '$($error[0].Exception.GetType().FullName)'." -Indent
        add-LogEntry -Message "Error on line number: '$($error[0].invocationinfo.ScriptLineNumber)'." -Indent
    }
    if(Test-Path -Path $LogFile)
    {
        $NewlogStart = (Select-String -Pattern 'Starting script' $LogFile | Select-Object -ExpandProperty LineNumber | Select-Object -Last 1) - 1
        $NewLogContent = Get-Content -Path $LogFile | Select-Object -Skip $NewlogStart
        $TotalErrors = $NewLogContent | Select-String -Pattern '[ERROR]' -SimpleMatch
        $TotalWarnings = $NewLogContent | Select-String -Pattern '[WARNING]' -SimpleMatch
    }
    Else
    {
        $TotalErrors = $NewLogContent | Select-String -Pattern '[ERROR]' -SimpleMatch
        $TotalWarnings = $NewLogContent | Select-String -Pattern '[WARNING]' -SimpleMatch
    }

    $ResultString = 'It completed with'
    if($TotalErrors -and $TotalWarnings)
    {
        $ResultString += " $($TotalErrors.Count) errors and $($TotalWarnings.Count) warnings"
    }
    elseif($TotalErrors)
    {
        $ResultString += " $($TotalErrors.count) errors"
    }
    elseif($TotalWarnings)
    {
        $ResultString += " $($TotalWarnings.count) warnings"
    }
    else
    {
        $ResultString += 'out any errors'
    }
    add-LogEntry -Output "The script took $TimeTaken. Exit code: $ExitCode. $ResultString."
    exit
}