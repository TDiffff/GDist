# GDist
WMI &amp; Powershell Distant tools

# Author  : Lana Ferry
# Purpose : Administrate distant computer using WMI and powershell

## GDist-Command      Computer Command(s)  : Send PowerShell Commands to a remote computer (Without feedback, not visible to user)
## GDist-SchTask      Computer Command(s)  : Send PowerShell Commands to a remote computer using a scheduled task ran as SYSTEM (Without feedback, not visible to user)

## GDist-GetService     Computer ServiceNam* : Get WMI service(s) object(s) from a remote computer and return the WMI objects
## GDist-StartService   Computer ServiceNam* : Start service(s) on a distant computer and get the result
## GDist-StopService    Computer ServiceNam* : Stop a service(s) on a distant computer and get the result

## GDist-GetProcess     Computer ProcessNam* : Get process(es) from a distant computer and return the WMI objects
## GDist-StartProcess   Computer ProcessName : Start a process on a distant computer and get the result
## GDist-StopProcess    Computer ProcessName : Stop a process on a distant computer and get the result

## GDist-Explore        Computer Share       : Opens an explorer at the location of an admin share (C$, ADMIN$ etc)
## GDist-CompMgmt       Computer             : Opens the computer managment of said computer

## GDist-GetSysInfos    Computer             : Get the System's OS Infos about a computer and return the WMI objects
## GDist-GetDomainInfos Computer             : Get the System's Domain Infos about a computer and return the WMI objects
## GDist-NetworkAdapter Computer             : Get Network Adapters Infos from a distant computer and return the results
## GDist-GetHardDrives  Computer             : Get volume informations of harddrives from a distant computer and return the results
## GDist-GetCompFiles   Computer             : Get the list of compressed files on a distant computer and return the results
## GDist-GetSofts       Computer             : Get the list of installed Softwares on a distant computer and return the results

## GDist-SendMail "From" "To" "Subject" "Body" "SMTP Server" : Send a mail using an annonymous access SMTP server

# Internal Commands (don't use these, they are used by other commands that require them)

### Test-Host        Computer             : Test the connectivity and the hostname <=> IP Address association of a distant computer
### Remove-Comments  FilePath ScriptBlock : Remove comments from a script before sending the commands containing it to a distant computer
