#This will undelete from AD recycle bin
Get-ADObject -Filter {isDeleted -eq $true} -IncludeDeletedObjects -Properties * | Restore-ADObject
