Get-DbaDatabase -SqlInstance 'localhost' -Database AdventureWorksLT2012 | Invoke-DbaDbClone -CloneDatabase 'AdventureWorksLT2012_clone_6.4'