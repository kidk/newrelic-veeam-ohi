<#
 #Requires PS -Version 3.0
 #Requires -Modules VeeamPSSnapIn
 #>

[cmdletbinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
        [string] $BRHost = "127.0.0.1",
    [Parameter(Position=1, Mandatory=$false)]
        $interval = "5" # Number of minutes
)

#region: Start Load VEEAM Snapin (if not already loaded)
if (!(Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue)) {
        if (!(Add-PSSnapin -PassThru VeeamPSSnapIn)) {
                # Error out if loading fails
                Write-Error "`nERROR: Cannot load the VEEAM Snapin."
                Exit
        }
}
#endregion

#region: Functions
Function Get-vPCRepoInfo {
[CmdletBinding()]
        param (
                [Parameter(Position=0, ValueFromPipeline=$true)]
                [PSObject[]]$Repository
                )
        Begin {
                $outputAry = @()
                Function Build-Object {param($name, $repohost, $path, $free, $total)
                        $repoObj = New-Object -TypeName PSObject -Property @{
                                Target = $name
                                                                        RepoHost = $repohost
                                Storepath = $path
                                StorageFree = [Math]::Round([Decimal]$free/1GB,2)
                                StorageTotal = [Math]::Round([Decimal]$total/1GB,2)
                                FreePercentage = [Math]::Round(($free/$total)*100)
                        }

                        Return $repoObj | Select-Object Target, RepoHost, Storepath, StorageFree, StorageTotal, FreePercentage
                }
        }
        Process {
                Foreach ($r in $Repository) {
                        # Refresh Repository Size Info
                        [Veeam.Backup.Core.CBackupRepositoryEx]::SyncSpaceInfoToDb($r, $true)

                        If ($r.HostId -eq "00000000-0000-0000-0000-000000000000") {
                                $HostName = ""
                        }
                        Else {
                                $HostName = $($r.GetHost()).Name.ToLower()
                        }

                        $outputObj = Build-Object $r.Name $Hostname $r.Path $r.info.CachedFreeSpace $r.Info.CachedTotalSpace
                }
                $outputAry += $outputObj
        }
        End {
                $outputAry
        }
}
#endregion

#region: Start BRHost Connection
$OpenConnection = (Get-VBRServerSession).Server
if($OpenConnection -eq $BRHost) {

} elseif ($null -eq $OpenConnection ) {
        Connect-VBRServer -Server $BRHost
} else {
        Disconnect-VBRServer
        Connect-VBRServer -Server $BRHost
}

$NewConnection = (Get-VBRServerSession).Server
if ($null -eq $NewConnection ) {
        Write-Error "`nError: BRHost Connection Failed"
        Exit
}
#endregion

#region: Collect and filter Sessions

# Get all Proxies
$viProxyList = Get-VBRViProxy

# Get all Repositories
$repoList = Get-VBRBackupRepository

# Get all Sessions (Backup/BackupCopy/Replica)
$allSesh = Get-VBRBackupSession

# Get all Restore Sessions
$allResto = Get-VBRRestoreSession

# Gather all Backup sessions within timeframe
$seshListBk = @($allSesh | Where-Object{($_.CreationTime -ge (Get-Date).AddMinutes(-$interval)) -and $_.JobType -eq "Backup"})
# Gather all BackupCopy sessions within timeframe
$seshListBkc = @($allSesh | Where-Object{($_.CreationTime -ge (Get-Date).AddMinutes(-$interval)) -and $_.JobType -eq "BackupSync"})
# Gather all Replication sessions within timeframe
$seshListRepl = @($allSesh | Where-Object{($_.CreationTime -ge (Get-Date).AddMinutes(-$interval)) -and $_.JobType -eq "Replica"})

#endregion

#region: Collect Jobs
# Gather Backup jobs
$allJobsBk = @(Get-VBRJob | Where-Object {$_.JobType -eq "Backup"})
# Gather BackupCopy jobs
$allJobsBkC = @(Get-VBRJob | Where-Object {$_.JobType -eq "BackupSync"})
# Get Replica jobs
$repList = @(Get-VBRJob | Where-Object{$_.IsReplica})
#endregion

#region: Get Backup session informations
$totalxferBk = 0
$totalReadBk = 0
$seshListBk | ForEach-Object{$totalxferBk += $([Math]::Round([Decimal]$_.Progress.TransferedSize/1GB, 0))}
$seshListBk | ForEach-Object{$totalReadBk += $([Math]::Round([Decimal]$_.Progress.ReadSize/1GB, 0))}
#endregion

#region: Preparing Backup Session Reports
$successSessionsBk = @($seshListBk | Where-Object{$_.Result -eq "Success"})
$warningSessionsBk = @($seshListBk | Where-Object{$_.Result -eq "Warning"})
$failsSessionsBk = @($seshListBk | Where-Object{$_.Result -eq "Failed"})
$runningSessionsBk = @($allSesh | Where-Object{$_.State -eq "Working" -and $_.JobType -eq "Backup"})
$failedSessionsBk = @($seshListBk | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
#endregion

#region:  Preparing Backup Copy Session Reports
$successSessionsBkC = @($seshListBkC | Where-Object{$_.Result -eq "Success"})
$warningSessionsBkC = @($seshListBkC | Where-Object{$_.Result -eq "Warning"})
$failsSessionsBkC = @($seshListBkC | Where-Object{$_.Result -eq "Failed"})
$runningSessionsBkC = @($allSesh | Where-Object{$_.State -eq "Working" -and $_.JobType -eq "BackupSync"})
$IdleSessionsBkC = @($allSesh | Where-Object{$_.State -eq "Idle" -and $_.JobType -eq "BackupSync"})
$failedSessionsBkC = @($seshListBkC | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})
#endregion

#region: Preparing Replicatiom Session Reports
$successSessionsRepl = @($seshListRepl | Where-Object{$_.Result -eq "Success"})
$warningSessionsRepl = @($seshListRepl | Where-Object{$_.Result -eq "Warning"})
$failsSessionsRepl = @($seshListRepl | Where-Object{$_.Result -eq "Failed"})
$runningSessionsRepl = @($allSesh | Where-Object{$_.State -eq "Working" -and $_.JobType -eq "Replica"})
$failedSessionsRepl = @($seshListRepl | Where-Object{($_.Result -eq "Failed") -and ($_.WillBeRetried -ne "True")})

$RepoReport = $repoList | Get-vPCRepoInfo | Select-Object       @{Name="Repository Name"; Expression = {$_.Target}},
                                                                @{Name="Host"; Expression = {$_.RepoHost}},
                                                                @{Name="Path"; Expression = {$_.Storepath}},
                                                                @{Name="Free (GB)"; Expression = {$_.StorageFree}},
                                                                @{Name="Total (GB)"; Expression = {$_.StorageTotal}},
                                                                @{Name="Free (%)"; Expression = {$_.FreePercentage}} | `
                                                                Sort "Repository Name"
#endregion

#region: Number of Endpoints
$number_endpoints = 0
foreach ($endpoint in Get-VBREPJob ) {
        $number_endpoints++;
}
#endregion

#region: Create New Relic metrics output
$metrics = @()
$metrics += @{
        "event_type" = "Veeam_Status"
        "SuccessfulBackups"  = $successSessionsBk.Count
        "WarningBackups" = $warningSessionsBk.Count
        "FailesBackups" = $failsSessionsBk.Count
        "FailedBackups" = $failedSessionsBk.Count
        "RunningBackups" = $runningSessionsBk.Count
        "WarningBackupCopys" = $warningSessionsBkC.Count
        "FailesBackupCopys" = $failsSessionsBkC.Count
        "FailedBackupCopys" = $failedSessionsBkC.Count
        "RunningBackupCopys" = $runningSessionsBkC.Count
        "IdleBackupCopys" = $IdleSessionsBkC.Count
        "SuccessfulReplications" = $successSessionsRepl.Count
        "WarningReplications" = $warningSessionsRepl.Count
        "FailesReplications" = $failsSessionsRepl.Count
        "FailedReplications" = $failedSessionsRepl.Count
        "RunningReplications" = $RunningSessionsRepl.Count
        "ProtectedEndpoints" = $number_endpoints
        "TotalBackupRead" = $totalReadBk
}

foreach ($Repo in $RepoReport) {
        $metrics += @{
                "event_type" = "Veeam_Repo"
                "Name" = "REPO " + $Repo."Repository Name" -replace '\s','_'
                "Free" = $Repo."Free (%)"
        }
}

$output = @{
        "name" = "kidk.newrelic.veeam"
        "protocol_version" = "3"
        "integration_version" = "1.0"
        "data" = @(
                @{
                        "entity" = @{
                                "name" = $BRHost
                                "type" = "veeam-server"
                                "id_attributes" = @(
                                        @{
                                                "key" = "environment"
                                                "value" = "production"
                                        },
                                        @{
                                                "key" = "environment"
                                                "value" = "production"
                                        }
                                )
                        }
                        "metrics" = $metrics
                        "inventory" = $()
                        "events" = $()
                }
        )
}

$outputJson = $output | ConvertTo-Json -Depth 10
Write-Host $outputJson
#endregion
