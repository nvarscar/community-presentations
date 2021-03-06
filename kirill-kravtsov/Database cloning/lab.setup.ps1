
# Constants

$instance1 = 'localhost'
$instance2 = 'localhost\I2'
$labFolder = '.\Lab'
$backupFolder = 'C:\Backups' # Careful, The folder will be cleaned up from backups!
# Import
Import-Module dbatools

$server = $server1 = Connect-DbaInstance $instance1
$server2 = Connect-DbaInstance $instance2
$instances = $instance1, $instance2
$servers = @($server1, $server2)

# Cleanup
$backupFiles = Get-ChildItem $labFolder -Include '*.bak' -Recurse | Read-DbaBackupHeader -ServerInstance $server1
Remove-DbaDatabase -SqlInstance $instances -Database $backupFiles.DatabaseName -Confirm:$false
Get-DbaDatabase -SqlInstance $instances | ? Name -like *_clone_* | Remove-DbaDatabase -Confirm:$false


#Remove old backups
Get-ChildItem $backupFolder -Include '*.bak', '*.trn' -Recurse | Remove-Item

#Reset job history and backup history
$servers.Invoke('declare @date datetime = getdate(); EXECUTE msdb.dbo.sp_purge_jobhistory @oldest_date = @date')
$servers.Invoke('declare @date datetime = getdate(); EXECUTE msdb.dbo.sp_delete_backuphistory @oldest_date = @date')

#end of cleanup
#Create network share
New-SmbShare -Name Backups -Path $backupFolder -FullAccess .\users -ErrorAction SilentlyContinue

#Restore databases
Get-ChildItem $labFolder -Include '*.bak' -Recurse | Restore-DbaDatabase -SqlInstance $server1

#Run scripts
Get-ChildItem $labFolder -Include '*.sql' -Recurse | % { $server1.Invoke((Get-Content $_ -Raw)) }

#Run backups
foreach ($type in 'Full', 'Log', 'Diff', 'Log', 'Log') {
    Write-Host "Running $type backups"
    Get-DbaAgentJob -SqlInstance $instance1 | ? name -match $type| Start-DbaAgentJob -Wait
    (Get-DbaDatabase -SqlInstance $instance1).Invoke('CHECKPOINT')

}