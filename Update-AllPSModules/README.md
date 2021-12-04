# Update-AllPSModules

This script will update all locally installed PowerShell modules to the latest version it can find online. It will also attempt to update PackageManagement and PowerShellGet so that it can update to pre-release versions.

You can use the '-NoPreviews' switch to avoid modules with 'beta', 'nightly', 'preview' etc., in the name.

This is what it looks like while running:

![Image of Update-AllPSModules sample](https://github.com/kieranwalsh/img/blob/main/Update-AllPSModules%20Sample.png)

![Gif of Update-AllPSModules in action](https://github.com/kieranwalsh/img/blob/main/Update-AllPSModules.gif)