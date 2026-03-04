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

