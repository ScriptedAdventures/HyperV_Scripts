Import-Module Hyper-V

#Find Clusters on network
$Global:I = 0
$Clusters = Get-Cluster | Select @{Name = "Item"; Expression = { $Global:I++; $Global:I } }, Name
$ClusterCount = ($Clusters).count 
$LocalHostName = HOSTNAME.EXE


$OutFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$OutFileName = "VHDFind " + $(Get-Date -UFormat %c ) + ".CSV"
$OutPath = $OutFolder + "\" + $OutFileName

#create data structures
$VMRec = [ordered] @{
    "DiskVM"       = ""
    "VMHost"       = ""
    "DiskPath"     = ""
    "DiskSize(MB)" = ""
    "DiskFormat"   = ""
    "DiskType"     = ""
}
#create blank hashtable for append and output
$GLOBAL:VMTable = @()

Function ClusterBuster {
    param( [string]$HVHost)

    $VMs = Get-VM -ComputerName $HVHost.Name
    foreach ($VM in $VMs) {
        $HardDrives = $VM.HardDrives
        $VMRec["DiskVM"] = $VM.Name
        foreach ($HardDrive in $HardDrives) {
            $VHD = ($HardDrive.Path | Get-VHD)
            $VMRec["VMHost"] = $VHD.ComputerName
            $VMRec["DiskPath"] = $VHD.Path
            $VMRec["DiskSize(MB)"] = (($VHD.Size) / (1024 * 1024))
            $VMRec["DiskFormat"] = $VHD.VhdFormat
            $VMRec["DiskType"] = $VHD.VhdType
            $VMRec["DiskVM"] = ""
        }
        $objRecord = New-Object PSObject -Property $VMRec
        $Global:Table += $objRecord
    }
}

Function UserMenu {
    Write-Host "Clusters Found"
    if ($ClusterCount = 0 ) {
        Write-Host "No Cluster Found, Proceeding to Check for Local VMs"
        ClusterBuster -Host $LocalHostName
        Write-Host "File Exported to $($OutFolder)"

    }   elseif ($ClusterCount -eq 1) {
        Write-Host "Located One Cluster, $($Clusters) "
        ClusterBuster -Host $Clusters.Name
        Write-Host "File Exported to $($OutFolder)"
    
    
    }   elseif ($ClusterCount -ge 2) {
        Write-Host "Select Target Cluster from List"
        Write-Host "$($Clusters | FT Item, Name)"
        [int]$UserIn = Read-Host "Cluster #:"
        $UserIn = $UserIn - 1
        foreach ($HVHost in $Cluster[$UserIn]) {
            ClusterBuster -HVHost $HVHost
        }
        Write-Host "Running Queries"
        Write-Host "File Exported to $($OutFolder)"
        Write-Host "Where was more than one detected, would you like to run again? (Y/N)"
        $rerun = Read-Host ":"
        if ($rerun -like "y", -or $rerun -like "yes") {
            UserMenu
        }
    }
}

Write-Host "Looking for Clusters"
UserMenu