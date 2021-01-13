try {
    $result = $null
    $properties = "CanonicalName", "Displayname", "UserPrincipalName", "SamAccountName", "Department", "Title", "Enabled"
    $tmp = get-adgroupmember "Domain Admins" -recursive
    $result = foreach($t in $tmp) {
        Get-ADUser -Identity $t.distinguishedName -Properties $properties
    }
    $resultCount = @($result).Count
    $result = $result | Sort-Object -Property Displayname
    
    Write-information "Result count: $resultCount"
    
    if($resultCount -gt 0){
        foreach($r in $result){
            $returnObject = @{CanonicalName=$r.CanonicalName; Displayname=$r.Displayname; UserPrincipalName=$r.UserPrincipalName; SamAccountName=$r.SamAccountName; Department=$r.Department; Title=$r.Title; Enabled=$r.Enabled;}
            Write-output $returnObject
        }
    } else {
        return
    }
} catch {
    Write-error "Error generating report. Error: $($_.Exception.Message)"
    return
}
