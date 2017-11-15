# Prepare Environment
import-module AzureRM
$pass = ConvertTo-SecureString "YN5/u2KC0EwiwOoLGqiaGByHvB3DrFrlqKTSbAiAKw0=" -AsPlainText -Force
#Service Principal ID is defined in Azure Automation - Auszuführendes Konto
#Key is defined in Azure Active Directory - Automation - Keys
$cred = New-Object -TypeName pscredential -ArgumentList "95229bfc-64b4-479c-be59-668ee52e8553", $pass
Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId "38e69ad1-2007-434c-880e-4f9c1c98ac4b" -SubscriptionId "9bc20da0-8454-4a4e-ae08-ada2180eb46e"
$ResourceGroupName = "SampleCorp"
$domainName = "samplecorp.local"
$StorageType = "Standard_GRS"
$clientUserPw = ConvertTo-SecureString "1234%%abcd" -AsPlainText -Force
$clientCred = New-Object -TypeName pscredential -ArgumentList "sampleCorpAdmin", $clientUserPw
$domainAdminName = "samplecorpadmin@samplecorp.local"
$sqlServerName = "server-2017sql"
$domainCred = New-Object -TypeName pscredential -ArgumentList "$domainName\sampleCorpAdmin", $clientUserPw
function AddDomainAdminLoginToSql(){
    param(
        [Parameter(Mandatory=$true)]
        $clientCred,
        [Parameter(Mandatory=$true)]
        $serverName,
        [Parameter(Mandatory=$true)]
        $domainAdminName
    )
    Invoke-Command -ComputerName samplecorpsql.northeurope.cloudapp.azure.com -Credential $clientCred -ArgumentList $serverName, $domainAdminName -ScriptBlock {
        param($serverName, $domainAdminName)
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
        write-host $serverName
        write-host $domainAdminName
        whoami
        Invoke-Sqlcmd -Query "CREATE LOGIN [samplecorp\samplecorpadmin] FROM WINDOWS; EXEC sp_addsrvrolemember @loginame = N'samplecorp\samplecorpadmin', @rolename = N'sysadmin'" -ServerInstance $serverName
    }
}
AddDomainAdminLoginToSql -domainAdminName $domainAdminName -serverName $sqlServerName -clientCred $clientCred
