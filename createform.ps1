#HelloID variables
$PortalBaseUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("Users", "HID_administrators")

# Create authorization headers with HelloID API key
$pair = "$apiKey" + ":" + "$apiSecret"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$key = "Basic $base64"
$headers = @{"authorization" = $Key}
# Define specific endpoint URI
if($PortalBaseUrl.EndsWith("/") -eq $false){
    $PortalBaseUrl = $PortalBaseUrl + "/"
}
 
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }

    $host.UI.RawUI.ForegroundColor = $fc
}


$variableName = "HIDreportFolder"
$variableGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automation/variables/named/$variableName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.automationVariableGuid)) {
        #Create Variable
        $body = @{
            name = "$variableName";
            value = 'C:\HIDreports';
            secret = "false";
            ItemType = 0;
        }
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automation/variable")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $variableGuid = $response.automationVariableGuid

        Write-ColorOutput Green "Variable '$variableName' created: $variableGuid"
    } else {
        $variableGuid = $response.automationVariableGuid
        Write-ColorOutput Yellow "Variable '$variableName' already exists: $variableGuid"
    }
} catch {
    Write-ColorOutput Red "Variable '$variableName'"
    $_
}



$taskName = "AD-user-generate-table-report-domain-admins"
$taskGetAdUsersGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/automationtasks?search=$taskName&container=1")
    $response = (Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false) | Where-Object -filter {$_.name -eq $taskName}
  
    if([string]::IsNullOrEmpty($response.automationTaskGuid)) {
        #Create Task
  
        $body = @{
            name = "$taskName";
            useTemplate = "false";
            powerShellScript = @'
            try {
                $result = $null
                $properties = "CanonicalName", "Displayname", "UserPrincipalName", "SamAccountName", "Department", "Title", "Enabled"
                $tmp = get-adgroupmember "Domain Admins" -recursive
                $result = foreach($t in $tmp) {
                    Get-ADUser -Identity $t.distinguishedName -Properties $properties
                }
                $resultCount = @($result).Count
                $result = $result | Sort-Object -Property Displayname
                
                HID-Write-Status -Message "Result count: $resultCount" -Event Information
                HID-Write-Summary -Message "Result count: $resultCount" -Event Information
                
                if($resultCount -gt 0){
                    foreach($r in $result){
                        $returnObject = @{CanonicalName=$r.CanonicalName; Displayname=$r.Displayname; UserPrincipalName=$r.UserPrincipalName; SamAccountName=$r.SamAccountName; Department=$r.Department; Title=$r.Title; Enabled=$r.Enabled;}
                        Hid-Add-TaskResult -ResultValue $returnObject
                    }
                } else {
                    Hid-Add-TaskResult -ResultValue []
                }
                
            } catch {
                HID-Write-Status -Message "Error generating report. Error: $($_.Exception.Message)" -Event Error
                HID-Write-Summary -Message "Error generating report" -Event Failed
                
                Hid-Add-TaskResult -ResultValue []
            }
'@;
            automationContainer = "1";
            variables = @()
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskGetAdUsersGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Powershell task '$taskName' created: $taskGetAdUsersGuid"  
    } else {
        #Get TaskGUID
        $taskGetAdUsersGuid = $response.automationTaskGuid
        Write-ColorOutput Yellow "Powershell task '$taskName' already exists: $taskGetAdUsersGuid"
    }
} catch {
    Write-ColorOutput Red "Powershell task '$taskName'"
    $_
}
  
  
  
$dataSourceName = "AD-user-generate-table-report-domain-admins"
$dataSourceGetAdUsersGuid = ""
  
try {
    $uri = ($PortalBaseUrl +"api/v1/datasource/named/$dataSourceName")
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
  
    if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
        #Create DataSource
        $body = @{
            name = "$dataSourceName";
            type = "3";
            model = @(@{key = "CanonicalName"; type = 0}, @{key = "Department"; type = 0}, @{key = "Displayname"; type = 0}, @{key = "Enabled"; type = 0}, @{key = "SamAccountName"; type = 0}, @{key = "Title"; type = 0}, @{key = "UserPrincipalName"; type = 0});
            automationTaskGUID = "$taskGetAdUsersGuid";
            input = @()
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/datasource")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
          
        $dataSourceGetAdUsersGuid = $response.dataSourceGUID
        Write-ColorOutput Green "Task data source '$dataSourceName' created: $dataSourceGetAdUsersGuid"
    } else {
        #Get DatasourceGUID
        $dataSourceGetAdUsersGuid = $response.dataSourceGUID
        Write-ColorOutput Yellow "Task data source '$dataSourceName' already exists: $dataSourceGetAdUsersGuid"
    }
} catch {
    Write-ColorOutput Red "Task data source '$dataSourceName'"
    $_
}

 
 

$formName = 'AD - Report - Accounts member of "Domain admins"'
$formGuid = ""
  
try
{
    try {
        $uri = ($PortalBaseUrl +"api/v1/forms/$formName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
  
    if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true))
    {
        #Create Dynamic form
        $form = @"
        [
  {
    "templateOptions": {},
    "type": "markdown",
    "summaryVisibility": "Show",
    "body": "The following report will show local AD accounts that are member of the \\"Domain Admins\\" groups. Please wait while the data is loading...",
    "requiresTemplateOptions": false
  },
  {
    "key": "grid",
    "templateOptions": {
      "label": "Results",
      "grid": {
        "columns": [
          {
            "headerName": "Canonical Name",
            "field": "CanonicalName"
          },
          {
            "headerName": "Displayname",
            "field": "Displayname"
          },
          {
            "headerName": "UserPrincipalName",
            "field": "UserPrincipalName"
          },
          {
            "headerName": "Department",
            "field": "Department"
          },
          {
            "headerName": "Title",
            "field": "Title"
          },
          {
            "headerName": "Enabled",
            "field": "Enabled"
          }
        ],
        "height": 500,
        "rowSelection": "single"
      },
      "dataSourceConfig": {
        "dataSourceGuid": "$dataSourceGetAdUsersGuid",
        "input": {
          "propertyInputs": []
        }
      },
      "useFilter": true,
      "useDefault": false
    },
    "type": "grid",
    "summaryVisibility": "Hide element",
    "requiresTemplateOptions": true
  },
  {
    "key": "exportReport",
    "templateOptions": {
      "label": "Export report (local export on HelloID Agent server) (local export on HelloID Agent server)",
      "useSwitch": true,
      "checkboxLabel": "Yes",
      "mustBeTrue": true
    },
    "type": "boolean",
    "summaryVisibility": "Show",
    "requiresTemplateOptions": true
  }
]
"@
  
        $body = @{
            Name = "$formName";
            FormSchema = $form
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/forms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
  
        $formGuid = $response.dynamicFormGUID
        Write-ColorOutput Green "Dynamic form '$formName' created: $formGuid"
    } else {
        $formGuid = $response.dynamicFormGUID
        Write-ColorOutput Yellow "Dynamic form '$formName' already exists: $formGuid"
    }
} catch {
    Write-ColorOutput Red "Dynamic form '$formName'"
    $_
}
  
  
  
  
$delegatedFormAccessGroupGuids = @()

foreach($group in $delegatedFormAccessGroupNames) {
    try {
        $uri = ($PortalBaseUrl +"api/v1/groups/$group")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
        $delegatedFormAccessGroupGuid = $response.groupGuid
        $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
        Write-ColorOutput Green "HelloID (access)group '$group' successfully found: $delegatedFormAccessGroupGuid"
    } catch {
        Write-ColorOutput Red "HelloID (access)group '$group'"
        $_
    }
}
  
  
  
$delegatedFormName = 'AD - Report - Accounts member of "Domain admins"'
$delegatedFormGuid = ""
$delegatedFormCreated = $false
  
try {
    try {
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false
    } catch {
        $response = $null
    }
  
    if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
        #Create DelegatedForm
        $body = @{
            name = "$delegatedFormName";
            dynamicFormGUID = "$formGuid";
            isEnabled = "True";
            accessGroups = $delegatedFormAccessGroupGuids;
            useFaIcon = "True";
            faIcon = "fa fa-info-circle";
        }  
  
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/delegatedforms")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
  
        $delegatedFormGuid = $response.delegatedFormGUID
        Write-ColorOutput Green "Delegated form '$delegatedFormName' created: $delegatedFormGuid"
        $delegatedFormCreated = $true
    } else {
        #Get delegatedFormGUID
        $delegatedFormGuid = $response.delegatedFormGUID
        Write-ColorOutput Yellow "Delegated form '$delegatedFormName' already exists: $delegatedFormGuid"
    }
} catch {
    Write-ColorOutput Red "Delegated form '$delegatedFormName'"
    $_
}
  
$taskActionName = "AD-export-report-accounts-domain-admins"
$taskActionGuid = ""
  
try {
    if($delegatedFormCreated -eq $true) {    
        $body = @{
            name = "$taskActionName";
            useTemplate = "false";
            powerShellScript = @'
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
'@;
            automationContainer = "8";
            objectGuid = "$delegatedFormGuid";
            variables = @(@{name = "exportReport"; value = "{{form.exportReport}}"; typeConstraint = "string"; secret = "False"});
        }
        $body = $body | ConvertTo-Json
  
        $uri = ($PortalBaseUrl +"api/v1/automationtasks/powershell")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Verbose:$false -Body $body
        $taskActionGuid = $response.automationTaskGuid

        Write-ColorOutput Green "Delegated form task '$taskActionName' created: $taskActionGuid"
    } else {
        Write-ColorOutput Yellow "Delegated form '$delegatedFormName' already exists. Nothing to do with the Delegated Form task..."
    }
} catch {
    Write-ColorOutput Red "Delegated form task '$taskActionName'"
    $_
}