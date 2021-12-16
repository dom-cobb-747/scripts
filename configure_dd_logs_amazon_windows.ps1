<#
    .SYNOPSIS
    This PowerShell script is designed to install the latest Datadog agent seamlessly on windows 
    .PARAMETER APIKey
    The API Key for your datadog installation.
    .PARAMETER Location
    Where the MSI should be dropped. Defaults to C:\Windows\temp
    .PARAMETER DD_SITE
    Name of the host. "datadoghq.com"
    .PARAMETER Tags
    Tags to assign.
    .EXAMPLE
    .\configure_dd_logs_amazon_windows.ps1 -APIKey INSERTKEYHERE -TAGS staging,us-east-1,na
    .\configure_dd_logs_amazon_windows.ps1 -APIKey INSERTKEYHERE -TAGS staging,eu-central-1,emea
    .\configure_dd_logs_amazon_windows.ps1 -APIKey INSERTKEYHERE -TAGS staging,us-east-1,na,staging,eu-central-1,emea,staging,ap-southeast-2,anz
    Updated version of the script, now the installer is downloaded from the cloud'
#>

# 1. SETTING PARAMETERS
[CmdletBinding()]
Param(

    [Parameter(Mandatory=$True)]
    [string]   $APIKey,
 
    [ValidateScript ( { Test-Path $_ } ) ]
    [string]   $LOCATION = "D:\\temp",    
    [string]   $DD_SITE = "datadoghq.com",
    
    [Parameter(Mandatory=$True)]
    [string[]] $TAGS

)
begin{
    $MSI = "$LOCATION\\ddog.msi"
    If ( Test-path $MSI ) {
        Remove-Item $MSI -Force
    }
}
process{


#2 DOWNLOAD THE INSTALLER
$DDA_Installer = "aws s3 cp s3://onekey-ami-pipeline/agent-installers/datadog-agent-7-latest.amd64.msi D:\\temp\\ddog.msi"

Invoke-Expression $DDA_Installer

#3. INSTALL DATADOG AGENT

If ( $Tags ){
    $Expression = "msiexec /qn /i `"$MSI`" APIKEY=`"$APIKEY`" SITE=`"$DD_SITE`" TAGS=`"$($TAGS -join ",")`""
}
Else{
    $Expression = "msiexec /qn /i `"$MSI`" APIKEY=`"$APIKEY`" SITE=`"$DD_SITE`""
}

Write-Output "Commencing Installation"
Write-Output "This will take 2, 1  or less min."
Write-Verbose "Installation Command: $Expression"
Invoke-Expression $Expression  

# 4. SETTING CONFIG. LOCATION 
[string] $DDOG_CONFIG_DIR = "C:\ProgramData\Datadog\conf.d\onekey-scheduledservices\"

New-Item -Path $DDOG_CONFIG_DIR -ItemType "directory" -ea 0
New-Item "$DDOG_CONFIG_DIR\config.yaml" -ItemType "file" -ea 0

# DECOMMENT the next two lines only if it's the first time running the script  
#Install-Module -Name powershell-yaml -Force -Verbose -Scope CurrentUser
#Import-Module powershell-yaml

if ( $Tags.count -eq 3)  {
    
    $ConfigYaml = @"
    
    logs:
        - type: file
          path: 
          source: 'onekey-scheduledservices'
          service: 'onekey-scheduledservices'
          tags:'[env:$($TAGS[0]),region:$($TAGS[1]),onekey_regions:$($TAGS[2])]'   
"@
} elseif ( $Tags.count -eq 9) {
    $ConfigYaml = @"
    
    logs:
        - type: file
          path: D:\Logs\na-staging\onekey-scheduledservices\*.log
          source: 'onekey-scheduledservices'
          service: 'onekey-scheduledservices'
          tags:'[env:$($TAGS[0]),region:$($TAGS[1]),onekey_regions:$($TAGS[2])]' 
    logs:
        - type: file
          path: D:/logs/emea-staging/onekey-scheduledservices*.log
          source: 'onekey-scheduledservices'
          service: 'onekey-scheduledservices'
          tags:'[env:$($TAGS[3]),region:$($TAGS[4]),onekey_regions:$($TAGS[5])]'
    logs:
        - type: file
          path: D:/logs/anz-staging/onekey-scheduledservices*.log
          source: 'onekey-scheduledservices'
          service: 'onekey-scheduledservices'
          tags:'[env:$($TAGS[6]),region:$($TAGS[7]),onekey_regions:$($TAGS[8])]'  
"@

}

Set-Content -Path "$DDOG_CONFIG_DIR\config.yaml"  -Value $ConfigYaml

# pause to avoid errors when enabling logs
Start-Sleep -s 60

# 5. ENABLING LOGS
(Get-Content C:\ProgramData\Datadog\datadog.yaml).replace('# logs_enabled: false','logs_enabled: true') | Set-Content C:\ProgramData\Datadog\datadog.yaml


#delete installer.msi (optional)
#Remove-Item $MSI -Force


# 6. STOP AND START 
#stop-service datadogagent
#start-service datadogagent


}