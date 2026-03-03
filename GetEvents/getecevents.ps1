$logname = 'system'
$Newest = (Read-Host "Please enter the number of events you would like returned")
Get-EventLog -LogName $logname -Newest 3
