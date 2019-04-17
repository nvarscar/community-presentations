
# Don't you forget to open ZOOMIT!!!!
# Constants

$instance1 = 'localhost'
$backupFolder = 'c:\Backups' # Careful, The folder will be cleaned up from backups!
$mappedBackups = '/backups'
$password = 'dbatools.IO'

# adjust backup path for docker
Get-ChildItem $backupFolder | Remove-Item -Force
$null = New-Item $backupFolder -ItemType Directory -Force
$linuxBackupFolder = $backupFolder
if ($linuxBackupFolder.Contains(':')) {
    $linuxBackupFolder = "/" + ($linuxBackupFolder -replace '\:', '')
}
$linuxBackupFolder = $linuxBackupFolder -replace '\\', '/'

# remove old containers
docker stop dockersql1
docker rm dockersql1

# create a shared network
docker network create localnet

# start containers
docker run -p 1433:1433 --name dockersql1 `
    --network localnet --hostname dockersql1 `
    -v "$linuxBackupFolder`:$mappedBackups" `
    -d dbatools/sqlinstance

# Import
Import-Module dbatools

# defining variables and authentication
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword
$PSDefaultParameterValues = @{
    Disabled               = $false
    "*-Dba*:SqlCredential" = $cred
}

# wait for connection
do {
    Write-Host "waiting for docker image 1..."
    Start-Sleep 3
} until((Invoke-DbaQuery -SqlInstance $instance1 -Query 'select 1' -As SingleValue -WarningAction SilentlyContinue) -eq 1 )

Repair-DbaServerName -SqlInstance $instance1 -Confirm:$false
docker restart dockersql1

# wait for connection
do {
    Write-Host "waiting for docker image 1..."
    Start-Sleep 3
} until((Invoke-DbaQuery -SqlInstance $instance1 -Query 'select 1' -As SingleValue -WarningAction SilentlyContinue) -eq 1 )

$server1 = Connect-DbaInstance $instance1

# Copy backups to the backup folder
#Copy-Item .\Lab\*.bak $backupFolder

#Restore databases
#$mappedBackups | Restore-DbaDatabase -SqlInstance $server1
