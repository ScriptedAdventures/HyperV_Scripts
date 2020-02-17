
Function Check-HyperVPS {
    try {
        try {
            Import-Module Hyper-V
        }
        catch {
            Write-Host "Hyper-V PowerShell Module Not Installed"
            $installHVModule = Read-Host "Install Now? (Y/N):"
            if ($installHVModule -like "Y") {
                Install-Module Hyper-V -Force
                Import-Module Hyper-V
            }
        }
        
    }
    catch {
        Write-Error "Cannot Install HyperV Module"
        break 
    }
}



#Find Clusters on network
$Script:I = 0
$Script:LocalHostName = HOSTNAME.EXE

#Define some basics
$Script:OutPath = $Script:OutFolder + "\" + $OutFileName

$Script:OutFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)

#create data structures
$Script:VMRec = [ordered] @{
    "DiskVM"       = ""
    "VMHost"       = ""
    "DiskPath"     = ""
    "DiskSize(MB)" = ""
    "DiskFormat"   = ""
    "DiskType"     = ""
}
#create blank hashtable for append and output
$Script:VMTable = @()

Function Get-ClusterHosts {
    param($Cluster)
    $clustresult = Get-ClusterNode -Cluster $Script:Cluster | Where { $_.State -eq "Up" }
    Return $clustresult
}

Function Get-ClusterBuster {
    param($Cluster)
    $Script:Cluster = $Cluster

    $ClusterHosts = Get-ClusterHosts -Cluster $Script:Cluster.Name
    foreach ($Clusterhost in $ClusterHosts) {

        $VMs = Get-VM -ComputerName $ClusterHost.Name

        foreach ($VM in $VMs) {
            $HardDrives = $VM.HardDrives
            $Script:VMRec["DiskVM"] = $VM.Name
            foreach ($HardDrive in $HardDrives) {
                $VHD = ($HardDrive.Path | Get-VHD -ComputerName $ClusterHost.Name )
                $Script:VMRec["VMHost"] = $VHD.ComputerName
                $Script:VMRec["DiskPath"] = $VHD.Path
                $Script:VMRec["DiskSize(MB)"] = (($VHD.Size) / (1024 * 1024))
                $Script:VMRec["DiskFormat"] = $VHD.VhdFormat
                $Script:VMRec["DiskType"] = $VHD.VhdType
                $objRecord = New-Object PSObject -Property $VMRec
            }
            $Script:VMTable += $objRecord
        }
    }
    return $Script:VMTable
}

Function Get-UserMenu {
    Write-Host "Clusters Found"
    if ($Global:ClusterCount = 0 ) {
        $OutFileName = "VHDFind " + $($Script:LocalHostName) + " " + $(Get-Date -UFormat %Y-%m-%d ) + ".CSV"
        $Script:OutPath = $Script:OutFolder + "\" + $OutFileName
        Write-Host "No Cluster Found, Proceeding to Check for Local VMs"
        Get-ClusterBuster -Cluster $Script:LocalHostName | Sort DiskVM | Export-CSV -Path $Script:OutPath -NoTypeInformation
        Write-Host "File Exported to $($Script:OutPath)"

    }
    elseif ($Global:ClusterCount = 1) {
        Write-Host "Located One Cluster, $($Script:Clusters.Name) "
        Write-Host "Running Script"
        $OutFileName = "VHDFind " + $($Script:Clusters.Name) + " " + $(Get-Date -UFormat %Y-%m-%d ) + ".CSV"
        $Script:OutPath = $Script:OutFolder + "\" + $OutFileName
        Get-ClusterBuster -Cluster $Script:Clusters.Name | Sort DiskVM | Export-CSV -Path $($Script:OutPath) -NoTypeInformation
        Write-Host "File Exported to $($Script:OutFolder)"  
    
    }
    elseif ($Global:ClusterCount = < 2) {
        Write-Host "Select Target Cluster from List"
        Write-Host "$($Script:Clusters | FT Item, Name)"
        [int]$UserIn = Read-Host "Cluster #:"
        $UserIn = $UserIn - 1
        $SelectedCluster = $Script:Clusters[$UserIn]
        $OutFileName = "VHDFind " + $($SelectedCluster.Name) + " " + $(Get-Date -UFormat %Y-%m-%d ) + ".CSV"
        $Script:OutPath = $Script:OutFolder + "\" + $OutFileName
        Get-ClusterBuster -Cluster $SelectedCluster.Name | Sort DiskVM | Export-CSV -Path $Script:OutPath -NoTypeInformation
        Write-Host "Running Queries"
        Write-Host "File Exported to $($Script:OutFolder)"
        Write-Host "There was more than one Cluster detected, would you like to run again? (Y/N)"
        $rerun = Read-Host ":"
        if ($rerun -like "y") {
            Get-UserMenu
        }
    }
}

$Script:Clusters = Get-Cluster | Select @{Name = "Item"; Expression = { $Script:I++; $Script:I } }, Name
[int]$Global:ClusterCount = (Get-Cluster).count

Write-Host "Looking for Clusters"
Get-UserMenu 