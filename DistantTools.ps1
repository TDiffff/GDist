# Author  : Lana Ferry
# Purpose : Administrate distant computer using WMI and powershell

###########################################################
###################### Command Infos ######################
###########################################################

## GDist-Command      Computer Command(s)  : Send PowerShell Commands to a remote computer (Without feedback, not visible to user)
## GDist-SchTask      Computer Command(s)  : Send PowerShell Commands to a remote computer using a scheduled task ran as SYSTEM (Without feedback, not visible to user)
#
## GDist-GetService     Computer ServiceNam* : Get WMI service(s) object(s) from a remote computer and return the WMI objects
## GDist-StartService   Computer ServiceNam* : Start service(s) on a distant computer and get the result
## GDist-StopService    Computer ServiceNam* : Stop a service(s) on a distant computer and get the result
#
## GDist-GetProcess     Computer ProcessNam* : Get process(es) from a distant computer and return the WMI objects
## GDist-StartProcess   Computer ProcessName : Start a process on a distant computer and get the result
## GDist-StopProcess    Computer ProcessName : Stop a process on a distant computer and get the result
#
## GDist-Explore        Computer Share       : Opens an explorer at the location of an admin share (C$, ADMIN$ etc)
## GDist-CompMgmt       Computer             : Opens the computer managment of said computer
# 
## GDist-GetSysInfos    Computer             : Get the System's OS Infos about a computer and return the WMI objects
## GDist-GetDomainInfos Computer             : Get the System's Domain Infos about a computer and return the WMI objects
## GDist-NetworkAdapter Computer             : Get Network Adapters Infos from a distant computer and return the results
## GDist-GetHardDrives  Computer             : Get volume informations of harddrives from a distant computer and return the results
## GDist-GetCompFiles   Computer             : Get the list of compressed files on a distant computer and return the results
## GDist-GetSofts       Computer             : Get the list of installed Softwares on a distant computer and return the results
#
## GDist-SendMail "From" "To" "Subject" "Body" "SMTP Server" : Send a mail using an annonymous access SMTP server

# Internal Commands (don't use these, they are used by other commands that require them)

##############
### Test-Host        Computer             : Test the connectivity and the hostname <=> IP Address association of a distant computer
### Remove-Comments  FilePath ScriptBlock : Remove comments from a script before sending the commands containing it to a distant computer
##############

###################################################################
###################### Powershell Execution  ######################
###################################################################

# If we're not admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch as an elevated process:
  Start-Process powershell.exe -ArgumentList "-sta -NoE -exec Bypass -File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
  exit
}

$credential = Get-Credential "admin account goes here"

# Remove comments and linefeeds of a script and return a string object
function Remove-Comments {
    [CmdletBinding(DefaultParameterSetName='FilePath' )] Param ([Parameter(Position=0,Mandatory=$True,ParameterSetName='FilePath' )][ValidateNotNullOrEmpty()][String]$Path,
    [Parameter(Position=0,ValueFromPipeline=$True,Mandatory=$True,ParameterSetName='ScriptBlock')][ValidateNotNullOrEmpty()][ScriptBlock]$ScriptBlock)Set-StrictMode -Version 2;
    if($PSBoundParameters['Path']){gci $Path -ErrorAction Stop|Out-Null;$ScriptBlockString=[IO.File]::ReadAllText((Resolve-Path $Path));$ScriptBlock=[ScriptBlock]::Create($ScriptBlockString);
    }else{$ScriptBlockString=$ScriptBlock.ToString()}$Tokens=[System.Management.Automation.PSParser]::Tokenize($ScriptBlock,[Ref]$Null)|Where{$_.Type-ne'Comment'};$StringBuilder=New-Object Text.StringBuilder;
    $CurrentColumn=1;$NewlineCount=0;foreach($CurrentToken in $Tokens){if(($CurrentToken.Type-eq'NewLine')-or($CurrentToken.Type-eq'LineContinuation')){$CurrentColumn=1;if($NewlineCount-eq0){$StringBuilder.AppendLine()|Out-Null}
    $NewlineCount++}else{$NewlineCount=0;if($CurrentColumn-lt$CurrentToken.StartColumn){if($CurrentColumn-ne1){$StringBuilder.Append(' ')|Out-Null}}$CurrentTokenEnd=$CurrentToken.Start+$CurrentToken.Length-1;
    if(($CurrentToken.Type-eq'String')-and($CurrentToken.EndLine-gt$CurrentToken.StartLine)){$LineCounter=$CurrentToken.StartLine;$StringLines=$(-join$ScriptBlockString[$CurrentToken.Start..$CurrentTokenEnd]-split'`r`n');
    foreach($StringLine in $StringLines){$StringBuilder.Append($StringLine)|Out-Null;$LineCounter++ }}else{$StringBuilder.Append((-join $ScriptBlockString[$CurrentToken.Start..$CurrentTokenEnd]))|Out-Null}
    $CurrentColumn=$CurrentToken.EndColumn}}Write-Output([ScriptBlock]::Create($StringBuilder.ToString()))
}

# Execute powershell command(s) or script (use Remove-Comments) on a distant computer
function GDist-Command ([string] $ComputerName, [string] $Cmd) {
    if (!(Test-Host $ComputerName)) { return }
    $sEncodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("&{" + $Cmd + "}"));
    $oResult = iwmi -ComputerName $ComputerName -Path win32_process -Name create -ArgumentList "powershell -enc $sEncodedCommand";
    if ($oResult.ProcessId -gt 0) { return $true; } return $false;
}

function GDist-SchTask ([string] $ComputerName, [string] $Cmd) {
	if (!(Test-Host $ComputerName)) { return }
	$sEncodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("&{" + $Cmd + "}"));

	$sTask = @"
SchTasks.exe /Create /RU "SYSTEM" /SC ONCE /TN "PowershellAutoTask" /TR "powershell -enc $sEncodedCommand" /F /ST 00:00
SchTasks.exe /run /tn "PowershellAutoTask"
sleep 5
SchTasks.exe /delete /tn "PowershellAutoTask" /F
"@

	GDist-Command $ComputerName $sTask
}

################################################################
###################### Service Managment  ######################
################################################################

# Get service(s) from a distant computer
function GDist-GetService ([string] $ComputerName, [string] $ServiceName = "*") {
    if (!(Test-Host $ComputerName)) { return }
    $ServiceName = $ServiceName -replace '\*','%';
    return (gwmi -ComputerName $ComputerName -Query "SELECT * FROM Win32_Service WHERE Name LIKE '$ServiceName'");
}

# Start a distant service
function GDist-StartService ([string] $ComputerName, [string] $ServiceName = "*") {
    if (!(Test-Host $ComputerName)) { return }
    $aServices = GDist-GetService $ComputerName $ServiceName;
    if ($aServices -ne $null) {
        foreach ($oService in $aServices) {
            if (!$oService.Started) {
                return $oService.StartService();
            } else {
                write-host "The service $ServiceName is already running on $ComputerName";
            }
        }
    } else { write-host "No service with this name has been found."; }
}

# Stop a distant service
function GDist-StopService ([string] $ComputerName, [string] $ServiceName = "*") {
    if (!(Test-Host $ComputerName)) { return }
    $aServices = GDist-GetService $ComputerName $ServiceName;  
    if ($aServices -ne $null) {
        foreach ($oService in $aServices) {
            if ($oService.Started) {
                return $oService.StopService();
            } else {
                write-host "The service $ServiceName is not running on $ComputerName";
            }
        }
    } else { write-host "No service with this name has been found."; }
}

################################################################
###################### Process Managment  ######################
################################################################

# Get one or more distant process on a distant computer by name (accepts * wildcards)
function GDist-GetProcess ([string] $ComputerName, [string] $ProcessName = "*") {
    if (!(Test-Host $ComputerName)) { return }
    $ProcessName = $ProcessName -replace '\*','%';
    return (gwmi -ComputerName $ComputerName -Query "SELECT * FROM win32_process WHERE Name LIKE '$ProcessName'");
}

# Start a process on a distant computer
function GDist-StartProcess ([string] $ComputerName, [string] $ProcessName) {
    if (!(Test-Host $ComputerName)) { return }
    return (iwmi –ComputerName $ComputerName -Class win32_process -Name create -ArgumentList "$ProcessName");
}

# Stop one or more processes on a distant computer (accepts * wildcards)
function GDist-StopProcess ([string] $ComputerName, [string] $ProcessName) {
    if (!(Test-Host $ComputerName)) { return }
    $oProcesses = GDist-GetProcess $ComputerName $ProcessName
    
    if ($oProcesses -ne $null) {
        foreach ($oProcess in $oProcesses) {
            try {
                $sName = $oProcess.Name;
                $iRetVal = $oProcess.terminate();
                $iPID = $oProcess.handle;
            } catch {
                $sName = "null";
                $iRetVal = "-1";
                $iPID = "-1";
            }
             
            if($iRetVal.returnvalue -eq 0) {
                Write-Host "The process $sName `($iPID`) terminated successfully"
            }
            else {
                Write-Host "The process $sName `($iPID`) termination has some problems"
            }
        }
    } else { write-host "No process with this name has been found."; }
}

#################################################################
######################### File Managment ########################
#################################################################

# Opens an explorer at the location of an admin share (C$, ADMIN$ etc)
function GDist-Explore ([string] $ComputerName, [string] $DriveName = "C$") {
	if (!(Test-Host $ComputerName)) { return }
	Invoke-Item "\\$ComputerName\$DriveName"
	sleep 1
	$wshell = New-Object -ComObject wscript.shell;
	$wshell.SendKeys('$($credential.GetNetworkCredential().UserName){tab}')
	$wshell.SendKeys("$($credential.GetNetworkCredential().Password){enter}")
}

#################################################################
###################### System Informations ######################
#################################################################

# Get Operating System infos from a distant computer
function GDist-GetSysInfos ([string] $ComputerName, [bool] $TestHost = 0) {
    if ($TestHost -eq 0) {if (!(Test-Host $ComputerName)) { return }}
	
	$result1 = (gwmi -ComputerName $ComputerName -Class Win32_OperatingSystem -ea SilentlyContinue | Select-Object -Property *)
	$result2 = (gwmi -ComputerName $ComputerName -Class Win32_ComputerSystem -ea SilentlyContinue | Select-Object -Property *)
	query session /server:$ComputerName
	
	if ($result1 -and $result2) {
		return [PSCustomObject]@{
				OS = $result1.Caption
				Version = $result1.Version
				SystemType = $result2.SystemType
				ComputerName = $result1.CSName
				Domain = $result2.Domain
				User = $result2.UserName
				Model = $result2.Model
		};
	}
}

# Get Network Adapters infos from a distant computer
function GDist-NetworkAdapter ([string] $ComputerName) {
    if (!(Test-Host $ComputerName)) { return }
    return (gwmi -ComputerName $ComputerName -Class Win32_NetworkAdapter | Select-Object -Property *);
}

# Get the list of hard drive volumes on a distant computer
function GDist-GetHardDrives ([string] $ComputerName, [string] $SoftwareName = "*") {
    if (!(Test-Host $ComputerName)) { return }
    return (gwmi -ComputerName $ComputerName -Class Win32_LogicalDisk -Filter "DriveType=3" | 
				Select-Object DeviceID, VolumeName, 
						  @{Name="Size";Expression={[math]::round($_.size/1GB, 2)}},
						  @{Name="FreeSpace";Expression={[math]::round($_.freespace/1GB, 2)}} |
				Format-List *
		    );
}

# Get the list of compressed files on a distant computer
function GDist-GetCompFiles ([string] $ComputerName) {
    if (!(Test-Host $ComputerName)) { return }
    return (gwmi -ComputerName $ComputerName -Class CIM_DataFile -Filter "Compressed = 'True'");
}

# Get the list of installed softwares on a distant computer
function GDist-GetSofts ([string] $ComputerName, [string] $SoftwareName = "*") {
    if (!(Test-Host $ComputerName)) { return }
    $SoftwareName = $SoftwareName -replace '\*','%';
    return (gwmi -ComputerName $ComputerName -Query "SELECT * FROM Win32_Product WHERE Name LIKE '$SoftwareName'");
}

# Open Computer Managment of a given remote host
function GDist-CompMgmt ($ComputerName) {
	C:\windows\system32\compmgmt.msc /computer:\\$ComputerName
}

# Send a mail using UTC smtp Server
function GDist-SendMail ($From, $To, $Subject, $Body, $SMTPServer) {
    send-mailmessage -smtpServer $SMTPServer -from $From -to $To -subject $Subject -Body $Body
    Write-Host "Sent.";
}

# Make sure we are interacting with the correct host.
function Test-Host ([string] $ComputerName) {
    if (Test-Connection $ComputerName -q -count 1) {
        try {
            $RealName = (GDist-GetSysInfos $ComputerName 1).CSName;
			$IP = ((New-Object System.Net.NetworkInformation.Ping).Send("$ComputerName").Address).IPAddressToString
            if ($ComputerName -like "$RealName*" -or $ComputerName -like $IP) {
                return $true;
            } elseif ($RealName) {
                Write-Host "Warning : DNS records aren't up to date, computer $ComputerName is in reality $RealName."
            } else {
				Write-Host "Warning : Impossible to interact with $ComputerName using WMI."
			}
        } catch [System.UnauthorizedAccessException] {
            Write-Host "Warning : Not authorized to interact with $ComputerName";
        }
    } else {
        Write-Host "Can't connect to $ComputerName, aborting..."
    }
    return $false;
}

#########################################################
###################### Local Tools ######################
#########################################################

# Add a functionnality to spawn a system Shell while the session is locked (Win+P)
function Setup-SystemShell () {
    saps powershell {sl HKLM:\*e\M*\*T\C*\Im*;ni displayswitch.exe|cd;new-itemproperty . -N Debugger -Va notepad.exe}
}

# Remove the functionnality to spawn a system Shell while the session is locked (Win+P)
function Remove-SystemShell () {
    saps powershell {rm HKLM:\*e\M*\*T\C*\Im*\displayswitch.exe}
}

write-host "DistantTools loaded.`n"

write-host "Commands :`n"
write-host "* Distant Powershell :";
write-host "    - GDist-SchTask      ComputerName `"Commands`"";
write-host "    - GDist-Command      ComputerName `"Commands`"`n";
write-host "* Distant Services Managment :";
write-host "    - GDist-GetService   ComputerName `"ServiceNa*`"";
write-host "    - GDist-StartService ComputerName `"ServiceNa*`"";
write-host "    - GDist-StopService  ComputerName `"ServiceNa*`"`n";
write-host "* Distant Processes Managment :";
write-host "    - GDist-GetProcess   ComputerName `"ProcessNa*`"";
write-host "    - GDist-StartProcess ComputerName `"ProcessNa*`"";
write-host "    - GDist-StopProcess  ComputerName `"ProcessNa*`"`n";
write-host "* Distant File Managment :";
write-host "    - GDist-Explore   ComputerName `"Share`"`n";
write-host "* System Informations :";
write-host "    - GDist-GetSysInfos    ComputerName";
write-host "    - GDist-GetCompFiles   ComputerName";
write-host "    - GDist-GetDomainInfos ComputerName";
write-host "    - GDist-NetworkAdapter ComputerName";
write-host "    - GDist-HardDrives     ComputerName";
write-host "    - GDist-GetSofts       ComputerName";
write-host "    - GDist-CompMgmt       ComputerName`n";
write-host "* Misc Commands :";
write-host "    - GDist-SendMail `"From`" `"To`" `"Subject`" `"Body`" `"SMTP Server`"";
write-host "* System Tools :";
write-host "    - Setup-SystemShell";
write-host "    - Remove-SystemShell`n";
