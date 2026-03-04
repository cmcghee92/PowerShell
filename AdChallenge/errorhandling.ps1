[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$WhatIf
)

Import-Module ActiveDirectory
# Enable Active Directory recycle bin
Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'Adatum.com' -Confirm:$false -WhatIf:$WhatIf
# Optional: restore deleted objects only when explicitly enabled
$RestoreDeletedObjects = $false
if ($RestoreDeletedObjects) {
    Get-ADObject -Filter "isDeleted -eq '$true'" -IncludeDeletedObjects -Property * | Restore-ADObject -WhatIf:$WhatIf
}


# Define the Organizational Unit (OU) and Group Name
$OUName = "London"
$DomainDN = "DC=Adatum,DC=com"
$OUPath = "OU=$OUName,$DomainDN"
$GroupName = "London Users"

$ouCreated = $false
$groupCreated = $false
$movedUsers = @()
$addedMembers = @()
$oldErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Stop'

    #PART 1
    # Check if the London OU already exists and if it doesn't, create it
    $existingOu = Get-ADOrganizationalUnit -Identity $OUPath -ErrorAction SilentlyContinue
    if (-not $existingOu) {
        # Create the OU
        New-ADOrganizationalUnit -Name $OUName -Path $DomainDN -ProtectedFromAccidentalDeletion $true -WhatIf:$WhatIf
        $ouCreated = $true
        Write-Output "Organizational Unit '$OUName' has been successfully created."
    }
    else {
        Write-Output "Organizational Unit '$OUName' already exists."
    }

    #PART 2
    # Check if the group already exists and create London Users group
    $existingGroup = Get-ADGroup -Identity $GroupName -ErrorAction SilentlyContinue
    if (-not $existingGroup) {
        # Create the Global Security Group inside the OU
        New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path $OUPath -WhatIf:$WhatIf
        $groupCreated = $true
        $existingGroup = Get-ADGroup -Identity $GroupName -ErrorAction Stop
        Write-Output "Group '$GroupName' has been successfully created in '$OUPath'."
    }
    else {
        Write-Output "Group '$GroupName' already exists."
    }
    $GroupDN = $existingGroup.DistinguishedName


#PART 3
# Find all users whose City property is 'London' and move them to the new OU and add them to the group
$OUtoSearch = (Read-Host "Enter the OU that you want to search for users")
$SearchBase = "OU=$($OUtoSearch),$($DomainDN)"
if (-not (Get-ADOrganizationalUnit -Identity $SearchBase -ErrorAction SilentlyContinue)) {
    throw "Search base '$SearchBase' does not exist."
}
$Users = Get-ADUser -Filter "City -eq 'London'" -Properties City, DistinguishedName -SearchBase $SearchBase

    # Move users to the new "London" OU and add them to "London Users" group
    foreach ($User in $Users) {
        $UserDN = $User.DistinguishedName
        $entry = [adsi]"LDAP://$UserDN"
        $originalParentDN = $entry.Parent -replace '^LDAP://', ''

        # Move the user to the London OU
        Move-ADObject -Identity $UserDN -TargetPath $OUPath -WhatIf:$WhatIf
        $movedUsers += [pscustomobject]@{
            DistinguishedName = $UserDN
            SamAccountName = $User.SamAccountName
            OriginalParentDN = $originalParentDN
        }
        Write-Output "Moved user '$($User.SamAccountName)' to OU: '$OUPath'."

        # Add the user to the "London Users" security group if not already a member
        $userGroupDns = (Get-ADUser -Identity $User.SamAccountName -Properties MemberOf).MemberOf
        if (-not ($userGroupDns -contains $GroupDN)) {
            Add-ADGroupMember -Identity $GroupName -Members $User.SamAccountName -WhatIf:$WhatIf
            $addedMembers += $User.SamAccountName
            Write-Output "Added user '$($User.SamAccountName)' to group '$GroupName'."
        }
        else {
            Write-Output "User '$($User.SamAccountName)' is already in group '$GroupName'."
        }
    }

    Write-Output "Task completed successfully."
}
catch {
    Write-Error "Operation failed. Rolling back changes. Error: $($_.Exception.Message)"

    foreach ($member in $addedMembers) {
        try {
            Remove-ADGroupMember -Identity $GroupName -Members $member -Confirm:$false -ErrorAction Stop -WhatIf:$WhatIf
            Write-Output "Rollback: removed '$member' from group '$GroupName'."
        }
        catch {
            Write-Warning "Rollback warning: could not remove '$member' from '$GroupName'."
        }
    }

    foreach ($moved in ($movedUsers | Select-Object -Last $movedUsers.Count)) {
        try {
            Move-ADObject -Identity $moved.DistinguishedName -TargetPath $moved.OriginalParentDN -ErrorAction Stop -WhatIf:$WhatIf
            Write-Output "Rollback: moved '$($moved.SamAccountName)' back to '$($moved.OriginalParentDN)'."
        }
        catch {
            Write-Warning "Rollback warning: could not move '$($moved.SamAccountName)' back to '$($moved.OriginalParentDN)'."
        }
    }

    if ($groupCreated) {
        try {
            Remove-ADGroup -Identity $GroupName -Confirm:$false -ErrorAction Stop -WhatIf:$WhatIf
            Write-Output "Rollback: removed group '$GroupName'."
        }
        catch {
            Write-Warning "Rollback warning: could not remove group '$GroupName'."
        }
    }

    if ($ouCreated) {
        try {
            Set-ADOrganizationalUnit -Identity $OUPath -ProtectedFromAccidentalDeletion $false -ErrorAction Stop -WhatIf:$WhatIf
            Remove-ADOrganizationalUnit -Identity $OUPath -Recursive -Confirm:$false -ErrorAction Stop -WhatIf:$WhatIf
            Write-Output "Rollback: removed OU '$OUName'."
        }
        catch {
            Write-Warning "Rollback warning: could not remove OU '$OUName'."
        }
    }

    throw
}
finally {
    $ErrorActionPreference = $oldErrorActionPreference
}


