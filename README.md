# PowerShell

[Add-LogEntry](https://github.com/kieranwalsh/PowerShell/blob/main/Add-LogEntry/add-LogEntry.ps1)
Similar to `Tee-Object`, this function will output data to the screen and a log file. However, it will timestamp the log file entries and allow for various indentations in the log, and colours in the host screen, depending on the data submitted.

[Get-NetworkLogons](https://github.com/kieranwalsh/PowerShell/tree/main/Get-NetworkLogons)
This script will search all AD computers (or ones matching the -ComputerName entry) and display the logged-on user if anyone. I mostly use it to find an unused end-user device to remote into and check if policies are applying how I expect.

[Get-Office365Forwarders](https://github.com/kieranwalsh/PowerShell/tree/main/Get-Office365Forwarders)
Lists all Office 365 mailboxes with rules to forward or redirect emails. Lists emails that go outside the tenancy by default, but can be used to include any internal redirects as well.

[Update-AllPSModules](https://github.com/kieranwalsh/PowerShell/tree/main/Update-AllPSModules)
Use this script to update installed PowerShell modules to the latest version it can find online. It will also attempt to update PackageManagement and PowerShellGet so that it can update to pre-release versions.
