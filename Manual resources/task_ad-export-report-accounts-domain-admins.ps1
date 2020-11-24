try {
    if($exportReport -eq "True") {
        ## export file properties
        if($HIDreportFolder.EndsWith("\") -eq $false){
            $HIDreportFolder = $HIDreportFolder + "\"
        }
        
        $timeStamp = $(get-date -f yyyyMMddHHmmss)
        $exportFile = $HIDreportFolder + "Report_AD_AccountsDomainAdmins_" + $timeStamp + ".csv"
        
        ## Report details
        $result = $null
        $properties = "CanonicalName", "Displayname", "UserPrincipalName", "SamAccountName", "Department", "Title", "Enabled"
        $tmp = get-adgroupmember "Domain Admins" -recursive
        $result = foreach($t in $tmp) {
            Get-ADUser -Identity $t.distinguishedName -Properties $properties
        }
        $resultCount = @($result).Count
        $result = $result | Sort-Object -Property Displayname
        
        ## export details
        $exportData = @()
        if($resultCount -gt 0){
            foreach($r in $result){
                $exportData += [pscustomobject]@{
                    "CanonicalName" = $r.CanonicalName;
                    "Displayname" = $r.Displayname;
                    "UserPrincipalName" = $r.UserPrincipalName;
                    "SamAccountName" = $r.SamAccountName;
                    "Department" = $r.Department;
                    "Title" = $r.Title;
                    "Enabled" = $r.Enabled;
                }
            }
        }
        
        $exportCount = @($exportData).Count
        HID-Write-Status -Message "Export row count: $exportCount" -Event Information
        
        $exportData = $exportData | Sort-Object -Property productName, userName
        $exportData | Export-Csv -Path $exportFile -Delimiter ";" -NoTypeInformation
        
        HID-Write-Status -Message "Report [$exportFile] containing $exportCount records created successfully" -Event Success
        HID-Write-Summary -Message "Report [$exportFile] containing $exportCount records created successfully" -Event Success
    }
} catch {
    HID-Write-Status -Message "Error generating report. Error: $($_.Exception.Message)" -Event Error
    HID-Write-Summary -Message "Error generating report" -Event Failed
    
    Hid-Add-TaskResult -ResultValue []
}