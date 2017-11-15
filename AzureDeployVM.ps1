function Invoke-AzureRmVmScript {
        [cmdletbinding()]
    param(
        # todo: add various parameter niceties
        [Parameter(Mandatory = $True,
                    Position = 0,
                    ValueFromPipelineByPropertyName = $True)]
        [string[]]$ResourceGroupName,
        
        [Parameter(Mandatory = $True,
                    Position = 1,
                    ValueFromPipelineByPropertyName = $True)]
        [string[]]$VMName,
        
        [Parameter(Mandatory = $True,
                    Position = 2)]
        [scriptblock]$ScriptBlock, #todo: add file support.
        
        [Parameter(Mandatory = $True,
                    Position = 3)]
        [string]$StorageAccountName,

        [string]$StorageAccountKey, #Maybe don't use string...

        $StorageContext,
        
        [string]$StorageContainer = 'scripts',
        
        [string]$Filename, # Auto defined if not specified...
        
        [string]$ExtensionName, # Auto defined if not specified

        [switch]$ForceExtension,
        [switch]$ForceBlob,
        [switch]$Force
    )
    begin
    {
        if($Force)
        {
            $ForceExtension = $True
            $ForceBlob = $True
        }
    }
    process
    {
        Foreach($ResourceGroup in $ResourceGroupName)
        {
            Foreach($VM in $VMName)
            {
                if(-not $Filename)
                {
                    $GUID = [GUID]::NewGuid().Guid -replace "-", "_"
                    $FileName = "$GUID.ps1"
                }
                if(-not $ExtensionName)
                {
                    $ExtensionName = $Filename -replace '.ps1', ''
                }

                $CommonParams = @{
                    ResourceGroupName = $ResourceGroup
                    VMName = $VM
                }

                Write-Verbose "Working with ResourceGroup $ResourceGroup, VM $VM"
                # Why would Get-AzureRMVmCustomScriptExtension support listing extensions regardless of name? /grumble
                Try
                {
                    $AzureRmVM = Get-AzureRmVM @CommonParams -ErrorAction Stop
                    $AzureRmVMExtended = Get-AzureRmVM @CommonParams -Status -ErrorAction Stop
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to retrieve existing extension data for $VM"
                    continue
                }

                # Handle existing extensions
                Write-Verbose "Checking for existing extensions on VM '$VM' in resource group '$ResourceGroup'"
                $Extensions = $null
                $Extensions = @( $AzureRmVMExtended.Extensions | Where {$_.Type -like 'Microsoft.Compute.CustomScriptExtension'} )
                if($Extensions.count -gt 0)
                {
                    Write-Verbose "Found extensions on $VM`:`n$($Extensions | Format-List | Out-String)"
                    if(-not $ForceExtension)
                    {
                        Write-Warning "Found CustomScriptExtension '$($Extensions.Name)' on VM '$VM' in Resource Group '$ResourceGroup'.`n Use -ForceExtension or -Force to remove this"
                        continue
                    }
                    Try
                    {
                        # Theoretically can only be one, so... no looping, just remove.
                        $Output = Remove-AzureRmVMCustomScriptExtension @CommonParams -Name $Extensions.Name -Force -ErrorAction Stop
                        if($Output.StatusCode -notlike 'OK')
                        {
                            Throw "Remove-AzureRmVMCustomScriptExtension output seems off:`n$($Output | Format-List | Out-String)"
                        }
                    }
                    Catch
                    {
                        Write-Error $_
                        Write-Error "Failed to remove existing extension $($Extensions.Name) for VM '$VM' in ResourceGroup '$ResourceGroup'"
                        continue
                    }
                }

                # Upload the script
                Write-Verbose "Uploading script to storage account $StorageAccountName"
                if(-not $StorageContainer)
                {
                    $StorageContainer = 'scripts'
                }
                if(-not $Filename)
                {
                    $Filename = 'CustomScriptExtension.ps1'
                }
                if(-not $StorageContext)
                {
                    if(-not $StorageAccountKey)
                    {
                        Try
                        {
                            $StorageAccountKey = (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroup -Name $storageAccountName -ErrorAction Stop)[0].value
                        }
                        Catch
                        {
                            Write-Error $_
                            Write-Error "Failed to obtain Storage Account Key for storage account '$StorageAccountName' in Resource Group '$ResourceGroup' for VM '$VM'"
                            continue
                        }
                    }
                    Try
                    {
                        $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
                    }
                    Catch
                    {
                        Write-Error $_
                        Write-Error "Failed to generate storage context for storage account '$StorageAccountName' in Resource Group '$ResourceGroup' for VM '$VM'"
                        continue
                    }
                }
        
                Try
                {
                    $Script = $ScriptBlock.ToString()
                    $LocalFile = [System.IO.Path]::GetTempFileName()
                    Start-Sleep -Milliseconds 500 #This might not be needed
                    Set-Content $LocalFile -Value $Script -ErrorAction Stop
            
                    $params = @{
                        Container = $StorageContainer
                        Context = $StorageContext
                    }

                    $Existing = $Null
                    $Existing = @( Get-AzureStorageBlob @params -ErrorAction Stop )

                    if($Existing.Name -contains $Filename -and -not $ForceBlob)
                    {
                        Write-Warning "Found blob '$FileName' in container '$StorageContainer'.`n Use -ForceBlob or -Force to overwrite this"
                        continue
                    }
                    $Output = Set-AzureStorageBlobContent @params -File $Localfile -Blob $Filename -ErrorAction Stop -Force
                    if($Output.Name -notlike $Filename)
                    {
                        Throw "Set-AzureStorageBlobContent output seems off:`n$($Output | Format-List | Out-String)"
                    }
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to generate or upload local script for VM '$VM' in Resource Group '$ResourceGroup'"
                    continue
                }

                # We have a script in place, set up an extension!
                Write-Verbose "Adding CustomScriptExtension to VM '$VM' in resource group '$ResourceGroup'"
                Try
                {
                    $Output = Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroup `
                                                                    -VMName $VM `
                                                                    -Location $AzureRmVM.Location `
                                                                    -FileName $Filename `
                                                                    -ContainerName $StorageContainer `
                                                                    -StorageAccountName $StorageAccountName `
                                                                    -StorageAccountKey $StorageAccountKey `
                                                                    -Name $ExtensionName `
                                                                    -TypeHandlerVersion 1.1 `
                                                                    -ErrorAction Stop

                    if($Output.StatusCode -notlike 'OK')
                    {
                        Throw "Set-AzureRmVMCustomScriptExtension output seems off:`n$($Output | Format-List | Out-String)"
                    }
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to set CustomScriptExtension for VM '$VM' in resource group $ResourceGroup"
                    continue
                }

                # collect the output!
                Try
                {
                    $AzureRmVmOutput = $null
                    $AzureRmVmOutput = Get-AzureRmVM @CommonParams -Status -ErrorAction Stop
                    $SubStatuses = ($AzureRmVmOutput.Extensions | Where {$_.name -like $ExtensionName} ).substatuses
                }
                Catch
                {
                    Write-Error $_
                    Write-Error "Failed to retrieve script output data for $VM"
                    continue
                }

                $Output = [ordered]@{
                    ResourceGroupName = $ResourceGroup
                    VMName = $VM
                    Substatuses = $SubStatuses
                }

                foreach($Substatus in $SubStatuses)
                {
                    $ThisCode = $Substatus.Code -replace 'ComponentStatus/', '' -replace '/', '_'
                    $Output.add($ThisCode, $Substatus.Message)
                }

                [pscustomobject]$Output
            }
        }
    }
}
function CreateVMs(){
    param(
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $vmRole,
        [Parameter(Mandatory=$true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory=$true)]
        [string]
        $Location,
        [Parameter(Mandatory=$true)]
        $ClientCred
    )
    
    ## Storage per ROle
    $StorageName = "samplecorpstorage$vmRole"

    ## Network per Role
    $InterfaceName = "Int06$vmRole"
    $Subnet1Name = "Subnet1"
    $VNetName = "VNet09"
    $VNetAddressPrefix = "10.0.0.0/16"
    $VNetSubnetAddressPrefix = "10.0.0.0/24"

    ## Compute per Role
    $VMName = "vm-2017$vmRole"
    $ComputerName = "server-2017$vmRole"
    $VMSize = "Standard_A2"
    $OSDiskName = $VMName + "OSDisk"

    # Storage per Role
    $StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Type $StorageType -Location $Location

    #Network per Role
    $PIp = New-AzureRmPublicIpAddress -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic -DomainNameLabel "samplecorp$vmRole"
    if ($vmRole -eq "dc"){
        $SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $Subnet1Name -AddressPrefix $VNetSubnetAddressPrefix
        $VNet = New-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $SubnetConfig
    }
    else{
        $VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
    }
    $Interface = New-AzureRmNetworkInterface -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $PIp.Id

    ## Create FW-Rule for WinRM (WinRM and RDP)
    $nsgName = "$VMName-nsg"
    $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Location $Location -Name $nsgName
    $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name "AllowWinRM" -Description "AutoAllow WinRM" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5985-5986 | Set-AzureRmNetworkSecurityGroup
    $nsg | Add-AzureRmNetworkSecurityRuleConfig -Name "AllowWinRDP" -Description "AutoAllow WinRDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 | Set-AzureRmNetworkSecurityGroup
    
    $Interface.NetworkSecurityGroup = $nsg
    Set-AzureRmNetworkInterface -NetworkInterface $Interface

    # Compute
    ## Setup VM object
    $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $clientCred -ProvisionVMAgent -EnableAutoUpdate
    switch ($vmRole){
        "dc"{
            $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version "latest"
            break
        } 
        "iis"{
            $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version "latest"
            break
        }
        "sql"{
            $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftSQLServer -Offer SQL2017-WS2016 -Skus Standard -Version "latest"
            break
        }
    }

    $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
    $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

    ## Create the VM in Azure
    $vm = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine

    ## Copy and run blob storage Script to enable PS Remoting inside VM
    $stgKey = Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $StorageAccount.StorageAccountName
    $stgKey = $stgKey[1].Value
    $stgContext = New-AzureStorageContext -StorageAccountName $StorageAccount.StorageAccountName -StorageAccountKey $stgKey
    New-AzureStorageContainer -Name "scripts" -Permission Container -Context $stgContext
    
    $params = @{
        ResourceGroupName = $ResourceGroupName
        VMName = $VMName
        StorageAccountName = $StorageAccount.StorageAccountName
    }
    Invoke-AzureRmVmScript @params -ForceExtension -ScriptBlock {
        Set-ExecutionPolicy "Unrestricted" -Force 
        Enable-PSRemoting -Force
        New-NetFirewallRule -DisplayName "Allow WinRM" -Direction Inbound –LocalPort 5985-5986 -Protocol TCP -Action Allow
    }    
    
}
function InstallADNode(){
    #Install ADDS Role
    param(
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $domainName,
        [Parameter(Mandatory=$true)]
        $ClientCred,
        [Parameter(Mandatory=$true)]
        $domainAdminPw
    )
    Invoke-Command -ComputerName samplecorpdc.northeurope.cloudapp.azure.com -Credential $clientCred -ArgumentList $domainAdminPw, $domainName -ScriptBlock {
        param($domainAdminPw, $domainName) 
        Install-windowsfeature AD-Domain-Services
        Import-Module ADDSDeployment
        Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "Win2012R2" -DomainName $domainName -DomainNetbiosName "SAMPLECORP" -ForestMode "Win2012R2" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true -SafeModeAdministratorPassword $domainAdminPw
        #Remove-DnsServerForwarder -IPAddress 10.0.0.8 -PassThru
    }
}
function InstallandJoinIISNode(){
    param(
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $domainName,
        [Parameter(Mandatory=$true)]
        $clientCred,
        [Parameter(Mandatory=$true)]
        $domainCred
    )
    Invoke-Command -ComputerName samplecorpiis.northeurope.cloudapp.azure.com -Credential $clientCred -ArgumentList $domainName, $domainCred  -ScriptBlock {
        param($domainName, $domainCred)
        add-windowsfeature Web-Server, Web-Security, Web-Filtering, Web-Windows-Auth, Web-Common-Http, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-Mgmt-Console
        while ((Test-Connection -ComputerName $domainName -Quiet) -eq $false){ Start-Sleep -Seconds 5 }
        Add-Computer -DomainName $domainName -Credential $domainCred -Restart -Force
    }
}
function JoinSqlNode( ){
    param(
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $domainName,
        [Parameter(Mandatory=$true)]
        $clientCred,
        [Parameter(Mandatory=$true)]
        $domainCred
    )
    Invoke-Command -ComputerName samplecorpsql.northeurope.cloudapp.azure.com -Credential $clientCred -ArgumentList $domainName, $domainCred -ScriptBlock {
        param($domainName, $domainCred)
        while ((Test-Connection -ComputerName $domainName -Quiet) -eq $false){ Start-Sleep -Seconds 5 }
        Add-Computer -DomainName $domainName -Credential $domainCred -Restart -Force
    }
}
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
        Invoke-Sqlcmd -Query "CREATE LOGIN [$domainAdminName] FROM WINDOWS; EXEC sp_addsrvrolemember @loginame = N'$domainAdminName', @rolename = N'sysadmin'" -ServerInstance $serverName
    }
}
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
$domainAdminName = "samplecorp\sampleCorpAdmin"
$sqlServerName = "server-2017sql"
$domainCred = New-Object -TypeName pscredential -ArgumentList "$domainName\sampleCorpAdmin", $clientUserPw

# Deploy resource group and vm's
$Location = "NorthEurope"
$resGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
CreateVMs -ResourceGroupName $ResourceGroupName -vmRole "dc" -Location $Location -ClientCred $clientCred
CreateVMs -ResourceGroupName $ResourceGroupName -vmRole "iis" -Location $Location -ClientCred $clientCred
CreateVMs -ResourceGroupName $ResourceGroupName -vmRole "sql" -Location $Location -ClientCred $clientCred

InstallADNode -domainName $domainName -ClientCred $clientCred -domainAdminPw $clientUserPw
# Set DNS Server for virtual network
$VNetName = "VNet09"
$VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
$VNet.DhcpOptions.DnsServers = "10.0.0.4"
Set-AzureRmVirtualNetwork -VirtualNetwork $VNet

#Restart VM's to get DNS settings
Get-AzureRmVM -ResourceGroupName $ResourceGroupName | % {
    Restart-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $_.Name
}

# Wait for WinRM Service IIS
Start-Sleep -Seconds 60
InstallandJoinIISNode -domainName $domainName -domainCred $domainCred -clientCred $clientCred
JoinSqlNode -domainName $domainName -domainCred $domainCred -clientCred $clientCred
# Wait for SQL to reboot after domain Join
Start-Sleep -Seconds 60
AddDomainAdminLoginToSql -domainAdminName $domainAdminName -serverName $sqlServerName -clientCred $clientCred
#Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force