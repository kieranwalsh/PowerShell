# Get-Office365Forwarders

This script was written after a customer's Office 365 tenancy was compromised and we needed to see if any accounts were sending email externally.

None of the existing solutions examined both Outlook rules, and forwarders set in the user's Office 365 settings.

You can examine just Outlook, or Office, by using the '-NoOffice365' or '-NoOutlook' switches.

By default  all Office 365 mailboxes are checked, but you can limit to certain accounts by using the '-EmailAddresses' switch.

As this was built to check for possible compromises it only lists forwarders/redirects to email outside of the tenancy. If you wish to see all email that is forwarded or redirected use the '-IncludeInternal' switch.

All data is saved to a CSV that you can specify with the '-CSVFile' switch. If no file is specified the data is saved to "C:\Windows\temp\Office 365 forwarding accounts.csv"

It looks like this while running:
![Gif of the script in action](https://github.com/kieranwalsh/img/blob/main/Get-Office365Forwarders.gif)

Here is an example of the CSV data:
![Image of the finished CSV data](https://github.com/kieranwalsh/img/blob/main/Get-Office365Forwarders%20-%20csv.png)
