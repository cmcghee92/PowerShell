#Define Variables
$OUName = "London"
$DomainDN = "DC=Adatum,DC=com"
$OUPath = "OU=$OUName,$DomainDN"
$GroupName = "London Users"

# Part1
#Create an OU only if ti does not already exist
if (-not (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OUPath } )) {
    # Create the OU
    New-ADOrganizationalUnit -Name $OUName -Path $DomainDN -ProtectedFromAccidentalDeletion $true
    Write-Output "Organizational Unit '$OUName' has been successfully created."
}
else {
    Write-Output "Organizational Unit '$OUName' already exists."
}

#PART 2
# Check if the group already exists and create London Users group
if (-not (Get-ADGroup -Filter { Name -eq $GroupName })) {
    # Create the Global Security Group inside the OU
    New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path $OUPath
    Write-Output "Group '$GroupName' has been successfully created in '$OUPath'."
}
else {
    Write-Output "Group '$GroupName' already exists."
}


#PART 3 and 4
# Find all users whose City property is 'London' in the Sale OU, 
# move them to the new OU, and add them to the group
$Users = Get-ADUser -Filter { City -eq "London" } -Properties City, DistinguishedName -searchBase "OU=Sales,$DomainDN"

# Move users to the new "London" OU and add them to "London Users" group
foreach ($User in $Users) {
    $UserDN = $User.DistinguishedName
    
    # Move the user to the London OU
    Move-ADObject -Identity $UserDN -TargetPath $OUPath
    Write-Output "Moved user '$($User.SamAccountName)' to OU: '$OUPath'."
    
    # Add the user to the "London Users" security group
    Add-ADGroupMember -Identity $GroupName -Members $User.SamAccountName
    Write-Output "Added user '$($User.SamAccountName)' to group '$GroupName'."
}

Write-Output "Script has completed successfully."