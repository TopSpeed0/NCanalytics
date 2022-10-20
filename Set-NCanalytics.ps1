$logs = "c:\logs"
Get-Date | Out-File $logs -Append
import-Module Microsoft.PowerShell.Utility

$Filer = "Cluster"
$vserver = "SVM"
# Add-NcCredential -Name $Filer # add cred if empty
try 
{
    if ($PSVersionTable.PSVersion.Major -ge 7) 
    {
         Remove-Module DataONTAP -Force -Confirm:$false -ErrorAction SilentlyContinue 
         Remove-Module Netapp.ONTAP -Force -Confirm:$false -ErrorAction SilentlyContinue 
         Remove-Module NetAppDocs -Force -Confirm:$false -ErrorAction SilentlyContinue 
         Import-Module NetApp.ONTAP -SkipEditionCheck #Requires 
    } 
    else 
    {
        $PSVersionTable.PSVersion.Major
        if  ($null -ne (Get-Module -ListAvailable *DataONTAP* )) { "DataONTAP" ; Import-Module DataONTAP -ErrorAction SilentlyContinue }
        if  ($null -ne (Get-Module -ListAvailable *Netapp.ONTAP* )) { "Netapp.ONTAP" ; Import-Module DataONTAP -ErrorAction SilentlyContinue } 
    }   
} catch 
{
$ErrorMessage = $_.Exception.Message
Write-Host "exiting script becuse we could not load DataONTAP error: $ErrorMessage"
"exiting script becuse we could not load DataONTAP error: $ErrorMessage" | Out-File $logs -Append
Pause
}

Connect-NcController -Name $Filer

$commandssh = "volume analytics show -vserver $($vserver)"

$Invoke = Invoke-NcSsh -name $Filer -Command $commandssh -Verbose 
$Value = $($Invoke.Value)
$Value = $Value.trim('')
$Value = $Value.split([Environment]::NewLine)
$Value = $Value |? {$_ -match $vserver}
$commandsshState = $Value | ConvertFrom-String -PropertyNames Vserver,Volume,State,Progress

if ( $commandsshState.state -eq 'initializing' ) {
    $initializing = $true
    $initializingvols = $commandsshState | ? {$_.state -eq 'initializing'}
    $initializingvolslist = $($initializingvols.volume.split([Environment]::NewLine))
} else {
    $initializing = $false
}

if ( $initializing -eq $true) {
    Write-host "INFO: Volumes $initializingvolslist are in initializing cant start new initialization until all Finished " -ForegroundColor Yellow
    "INFO: Volumes $($initializingvols.volume.split([Environment]::NewLine)) are in initializing cant start new initialization until all Finished " | Out-File $logs -Append
 break
} elseif ( $initializing -eq $false) {
    foreach ($volume in $commandsshState) {
        if ($volume.state -eq 'off') { 
                Write-host "INFO: Start Volume initialization on  $($volume.Volume) " -ForegroundColor Green
                "INFO: Start Volume initialization on  $($volume.Volume) " | Out-File $logs -Append
                $commandsshanalytics = "volume analytics on -vserver  $($vserver) -volume $($volume.Volume)"
                Invoke-NcSsh -name $Filer -Command $commandsshanalytics -Verbose
                break
        }   
    }
}


