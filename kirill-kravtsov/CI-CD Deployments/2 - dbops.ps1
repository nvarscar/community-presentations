$password = 'dbatools.IO'
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword

### Cleanup
Function cleanup { 
    $null = Remove-DbaDatabase -SqlInstance localhost -Database dbops -Confirm:$false -SqlCredential $cred
    Invoke-DbaQuery -SqlInstance localhost -Query "CREATE DATABASE dbops" -SqlCredential $cred
    New-Item -Path C:\Lab\dbops, C:\Lab\packages -ItemType Directory -Force | Out-Null
    Remove-Item C:\Lab\dbops\*, C:\Lab\packages\* -Recurse
    Copy-Item 'C:\Lab\builds\1. DB\*' C:\Lab\dbops -Recurse
    
}
cleanup
Reset-DBODefaultSetting -All

# Settings
##List default settings
Get-DBODefaultSetting


##Set default settings
Set-DBODefaultSetting -Name SqlInstance -Value localhost
Set-DBODefaultSetting -Name database -Value dbops
Set-DBODefaultSetting -Name Credential -Value $cred

# Simple deployments
## Execute sample script
Set-Location C:\
Install-DBOSqlScript -ScriptPath C:\Lab\dbops -SqlInstance localhost -Database dbops

## Validation
Invoke-DBOQuery -Query "SELECT schema_name(schema_id) as [Schema], name FROM sys.tables" | Out-GridView
Invoke-DBOQuery -Query "SELECT Id, ScriptName FROM SchemaVersions" | Out-GridView


## Add procedures to the list of deployment scripts
cleanup
Set-Location C:\Lab\dbops
Install-DBOSqlScript -ScriptPath .\*
Copy-Item 'C:\Lab\builds\7. Stored Procedures' C:\Lab\dbops -Recurse -PassThru | Select Name
Install-DBOSqlScript -ScriptPath .\*




# Packages and build system
## Building a package
cleanup
Set-Location C:\Lab\packages
New-DBOPackage -Name dbopsPackage -ScriptPath C:\Lab\dbops\* -Build 1.0 | Select-Object Name, Builds, Version


## Adding builds to the package
$newPackage = Add-DBOBuild -Path $package -ScriptPath 'C:\Lab\builds\7. Stored Procedures' -Build 2.0
$newPackage | Select-Object Name, Builds, Version
$newPackage.GetBuild('2.0').Scripts | Select-Object Name, Hash, PackagePath
$newPackage.GetBuild('1.0').Scripts[4].GetContent()


## Deploying package to a custom versioning table
$newPackage | Install-DBOPackage -DeploymentMethod SingleTransaction -SchemaVersionTable dbo.DeploymentLog

# Configuration
## Package configuration
Get-DBOPackage C:\Lab\packages\dbopsPackage.zip | Get-DBOConfig
Update-DBOConfig .\dbopsPackage.zip -Configuration @{DeploymentMethod='SingleTransaction'}
Get-DBOPackage C:\Lab\packages\dbopsPackage.zip | Get-DBOConfig

## Custom configurations
$config = @{ DeploymentMethod = 'TransactionPerFile' }
Install-DBOPackage .\dbopsPackage.zip -Configuration $config

## Configuration files
$config = Get-DBOPackage C:\Lab\packages\dbopsPackage.zip | Get-DBOConfig
$config.SchemaVersionTable
$config.SchemaVersionTable = 'dbo.DeploymentLog'
$config | Export-DBOConfig .\dbops.json 
notepad .\dbops.json
Install-DBOPackage .\dbopsPackage.zip -Configuration .\dbops.json

# CI/CD stuff
cleanup
Get-ChildItem .

## Create a new package using continuous integration features and automatic versioning
Invoke-DBOPackageCI -Name .\dbopsPackage.zip -ScriptPath C:\Lab\dbops\* -Version 0.5 | Select-Object Name, Builds, Version

## Augment the package with a new build using same source folder
Copy-Item 'C:\Lab\builds\7. Stored Procedures' C:\Lab\dbops -Recurse -PassThru | Select Name
Invoke-DBOPackageCI -Name .\dbopsPackage.zip -ScriptPath C:\Lab\dbops\* | Select-Object Name, Builds, Version
Get-DBOPackage .\dbopsPackage.zip | Select-Object -ExpandProperty Builds

### Essentially, the same as using 
Add-DBOBuild  -Name .\dbopsPackage.zip -ScriptPath C:\Lab\dbops\* -Build 0.5.3 -Type New | Select-Object Name, Builds, Version

## Store package in a repository
$dir = New-Item C:\Lab\packages\Repo -ItemType Directory
Publish-DBOPackageArtifact -Path .\dbopsPackage.zip -Repository $dir | Select-Object FullName, Length

## Deploy the package from a repository
Get-DBOPackageArtifact -Name dbopsPackage -Repository $dir | Install-DBOPackage