# Author: Roman PERRIN
# Changes the foler name of the selected user to the one specified.

param(
    [string]$oldUsername,
    [string]$newUsername
) 

# Privilege elevation
if (!
    #current role
    (New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    #is admin?
    )).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
) {
    #elevate script and exit current non-elevated runtime
    Start-Process `
        -FilePath 'powershell' `
        -ArgumentList (
            #flatten to single array
            '-File', $MyInvocation.MyCommand.Source, $args `
            | %{ $_ }
        ) `
        -Verb RunAs
    exit
}

function Get-MenuChoice
    {
    [CmdletBinding ()]
    Param
        (
        [Parameter (
            Mandatory,
            Position = 0
            )]
            [string[]]
            $MenuList,
 
        [Parameter (
            Position = 1
            )]
            [string]
            $Title,
 
        [Parameter (
            Position = 2
            )]
            [string]
            $Prompt = 'Please enter a number from the above list or "x" to exit '
            
        )
 
    $ValidChoices = 0..$MenuList.GetUpperBound(0) + 'x'
    $Choice = ''
    while ([string]::IsNullOrEmpty($Choice))
        {
        Write-Host $Title
        foreach ($Index in 0..$MenuList.GetUpperBound(0))
            {
            Write-Host ('{0} - {1}' -f $Index, $MenuList[$Index])
            }
        $Choice = Read-Host -Prompt $Prompt
        Write-Host ''
        
        if ($Choice.Length -eq 0) {
            Exit
        }

        if ($Choice -notin $ValidChoices)
            {
            [System.Console]::Beep(1000, 300)
            Write-Warning ''
            Write-Warning ('    [ {0} ] is not a valid selection.' -f $Choice)
            Write-Warning '    Please try again.'
            Write-Warning ''
 
            $Choice = ''
 
            pause
            }
        }
 
    # send it out to the caller
    if ($Choice -eq 'x')
        {
        'Exit'
        }
        else
        {
        $Choice
        }
    } # end >>> function Get-MenuChoice


# Getting the user
$users = Get-LocalUser | where-object Enabled -eq True | Select-Object -Property Name
if (!$oldUsername) {
    # Write-Host "No username provided"
    $index = (Get-MenuChoice -MenuList @($users."Name") -Title "Choose a user")
    $oldUsername = @($users."Name")[$index]
}
$oldPath = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$((Get-LocalUser $oldUsername).SID)" ProfileImagePath
Write-Host "User $oldusername selected. root folder current location: $oldPath"

# Getting the new name and path
if (!$newUsername) {
    # Write-Host "No new username provided"
    $newUsername = Read-Host -Prompt "Enter the new name for the folder"
    Write-Host ''
}
$profilesRootDir = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' ProfilesDirectory
$newPath = Join-Path $profilesRootDir $newUsername

Write-Host ''
Write-Host "$oldUsername's folder: $oldPath will be moved to: $newPath"

# Changing the entry in the registry
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$((Get-LocalUser $oldUsername).SID)" ProfileImagePath $newPath

# Renaming the folder
Rename-Item -Path $oldPath -NewName $newPath


# Rebuilding the search index
Set-service -Name WSearch -StartupType Disabled

if ((Get-Service -Name WSearch)."Status" -ne "Stopped") {
    Stop-Service -Name WSearch
}

$files = @(
    "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db"
    "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows-gather.db")

foreach ($file in $files) {
    if (Test-Path -Path $file) {
        Remove-Item $file
    }
}

while ((Get-Service -Name WSearch)."Status" -ne "Running") {
    try {
        Set-service -Name WSearch -StartupType Automatic
        Start-Service -Name WSearch -WarningAction SilentlyContinue
        Write-Host "indexing..."
    } catch {}
} 

Write-Host "indexing done"