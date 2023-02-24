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
        Last Updated: 2023-02-24
        Version: 0.10.02
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [Alias('Message')]
        [string]$Output = $(if(
            (-not($BlankLine)) -and
            (null -eq $Output)
            )
            {
                $Output = Read-Host 'Please specify the output you wish to log'
            }
            Elseif($BlankLine)
            {
                $Output = ''
            }
        ),
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
    if($BlankLine)
    {
        '{0,-22}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Out-File -FilePath $LogFile -Encoding 'utf8' -Append
    }
    Elseif($ClearLog)
    {
        "{0,-22}{1,-11}{2,-$Space}{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Type, ' ', $Output | Out-File -FilePath $LogFile -Encoding 'utf8'
    }
    Else
    {
        "{0,-22}{1,-11}{2,-$Space}{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Type, ' ', $Output | Out-File -FilePath $LogFile -Encoding 'utf8' -Append
    }
}