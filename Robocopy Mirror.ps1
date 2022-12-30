#Requires -Version 5.0
# This should really be version 7 but this breaks native windows right click behaviour as this still uses 5
# But 7 is needed for this script to function

###############################################################################################################################
#                                                                                                                             #
#  Powershell Script to mirror files using Robocopy                                                                           #
#  THIS IS A POTENTIALLY VERY DANGEROUS SCRIPT, YOU HAVE BEEN WARNED                                                          #
#  THIS WILL DELETE FILES AT THE DESTINATION THAT DO NOT EXIST AT THE SOURCE!                                                 #
#                                                                                                                             #
#  By Silvalined 2020                                                                                                         #
#                                                                                                                             #
###############################################################################################################################

###############################################################################################################################
### Version History																											###
###############################################################################################################################
# 1.0 : First release                                                                                                         #
# 1.1 : Added option to exclude directories                                                                                   #
# 1.2 : Added /MT to multithread, defaults as 8                                                                               #
###############################################################################################################################

###############################################################################################################################
### Adjustable Variables                                                                                                    ###
###############################################################################################################################

# If backing up from local then just set to '', otherwise input the name of the remote server hosting the source directory:
$sourceClient = 'ServerName'
# The source files you want to be backed up:
$sourceDir = '\\ServerName\Share\FolderName'
# If backing up to local then just set to '', otherwise input the name of the remote server hosting the destination directory:
$destinationClient = 'ServerName'
# !!!MAKE SURE destinationDir IS CORRECT AS IT WILL PURGE FILES THAT DO NOT EXIST AT THE SOURCE!!!
# !!!THE LAST FOLDER ON THE PATH SHOULD MATCH THE FOLDER FROM THE SOURCE!!!
$destinationDir = '\\ServerName\Share\FolderName'

# Set this to just '' if you dont want to exclude any directories
# If you want to exclude multiple directories then seperate them via spaces such as below:
# $excludedDir = '\\ServerName\Share\FolderName\ExcludedFolder1 \\ServerName\Share\FolderName\ExcludedFolder2'
$excludedDir = '\\ServerName\Share\FolderName\ExcludedFolder'

# Set this to just '' if you dont want to log
$logLocation = 'D:' 
# Retry attempts in case a file is unable to be read:
$retryAmount = 10
# Wait time in seconds:
$waitAmount = 6

# You probably dont wan't to change these:
# tempLocation needed in case we are running the script from a network share
# as elevation to local admin will not be able to read this script:
$tempLocation = 'C:\Temp'
$dateTime = Get-Date -Format "yy-MM-dd HH-mm-ss"

###############################################################################################################################
### Main Script - DO NOT CHANGE BELOW HERE                                                                                  ###
###############################################################################################################################

###############################################################################################################################
### Function(s)                                                                                                             ###
###############################################################################################################################

function Find-Credential {
    param( [string]$serverName)
    [string]$storedCreds = cmdkey.exe "/list:Domain:target=$serverName"

    if ($storedCreds -like '* NONE *') {
        Set-Credential($serverName)
    }
}

function Set-Credential {
    param( [string]$serverName)
    $username = Read-Host -Prompt 'Username?'
    $password = Read-Host -Prompt 'Password?' -AsSecureString
    cmdkey.exe /add:$serverName /user:$username /pass:(ConvertFrom-SecureString -SecureString $password -AsPlainText)
}

###############################################################################################################################
### End of Function(s)                                                                                                      ###
###############################################################################################################################

###############################################################################################################################
### Script Location Checker                                                                                                 ###
###############################################################################################################################

# Get the full path of this script
$ScriptPath = $MyInvocation.MyCommand.Path
# Remove the "file" part of the path so that only the directory path remains
$ScriptPath = Split-Path $ScriptPath
# Change location to where the script is being run
Set-Location $ScriptPath

###############################################################################################################################
### End of Script Location Checker                                                                                          ###
###############################################################################################################################

# Full path name to the temp script that we will be copying under:
[string]$tempScript = "$tempLocation\$($MyInvocation.MyCommand.Name)"

# Check if the temp directory exists, if not then creates it
if (!(Test-Path $tempLocation)) {
    New-Item -ItemType Directory -Path $tempLocation
}

# If we aren't an admin then run these commands:
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # Copy our script to a temp location to be run as admin:
    Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $tempLocation

    # Relaunch this temp script as an elevated process:
    Start-Process pwsh.exe "-File", ('"{0}"' -f $tempScript) -Verb RunAs

    # Exit (this current non admin session)
    exit
}

# Now running elevated so run the rest of the script:

# Check to see if we are running with at least PowerShell version 7 (needed for the '-AsPlainText' command to work)
if ($PSVersionTable.PSVersion.Major -lt 7)
{
    Write-Output 'You need at least PowerShell version 7 for this script to run'
    # Remove the temporary script
    Remove-Item -Path $tempScript
    Read-Host -Prompt "Press Enter to exit"
    exit
}

if ($sourceClient -ne '') {
    Find-Credential($sourceClient)
}

if ($destinationClient -ne '') {
    Find-Credential($destinationClient)
}

# Check if the destination directory exists, if not then creates it
if (!(Test-Path $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir
}

# Log on
if ($logLocation -ne '' -and $excludedDir -eq '') {
    Robocopy.exe $sourceDir $destinationDir /ZB /MIR /MT /E /R:$retryAmount /W:$waitAmount /TEE /COPY:DT /LOG:"$logLocation\Robocopy Log - $dateTime.log"
}
# Log on, exclude directory on
elseif ($logLocation -ne '' -and $excludedDir -ne '') {
    Robocopy.exe $sourceDir $destinationDir /ZB /MIR /MT /E /R:$retryAmount /W:$waitAmount /TEE /COPY:DT /LOG:"$logLocation\Robocopy Log - $dateTime.log" /XD $excludedDir
}
# Exclude directy on
elseif ($logLocation -eq '' -and $excludedDir -ne '') {
    Robocopy.exe $sourceDir $destinationDir /ZB /MIR /MT /E /R:$retryAmount /W:$waitAmount /TEE /COPY:DT /XD $excludedDir
}
# No Log or exclude directory
elseif ($logLocation -eq '' -and $excludedDir -eq '') {
    Robocopy.exe $sourceDir $destinationDir /ZB /MIR /MT /E /R:$retryAmount /W:$waitAmount /TEE /COPY:DT
}
# Catch all statement just in case
else {
    Write-Output 'SOMETHING WENT WRONG!'
}

# Remove the temporary script
Remove-Item -Path $tempScript

# Wait for the user to acknowledge with the enter key
Read-Host -Prompt "Press Enter to exit"
