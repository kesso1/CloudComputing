import-module AzureRM

$pass = ConvertTo-SecureString "W80RJe8mqPuITJLt2qz/roEATJ9BxdCo8TSoxjSurWQ=" -AsPlainText -Force
$cred = New-Object -TypeName pscredential -ArgumentList "4b3273ca-d65c-47bc-979a-9fd70c03fc44", $pass 
Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId 38e69ad1-2007-434c-880e-4f9c1c98ac4b -SubscriptionId 9bc20da0-8454-4a4e-ae08-ada2180eb46e

# Variables    
## Global
$ResourceGroupName = "SampleCorp"
$Location = "NorthEurope"

## Storage
$StorageName = "samplecorpstorage"
$StorageType = "Standard_GRS"

## Network
$InterfaceNameSql = "Int06Sql"
$InterfaceNameIIS = "Int06IIS"
$Subnet1Name = "Subnet1"
$VNetNameSql = "VNet09Sql"
$VNetNameIIS = "VNet09IIS"
$VNetAddressPrefix = "10.0.0.0/16"
$VNetSubnetAddressPrefix = "10.0.0.0/24"

## Compute
$VMNameSql = "Sql2017"
$ComputerNameSql = "SqlServer2017"
$VMNameIIS = "IIS2017"
$ComputerNameIIS = "IISServer2017"
$VMSize = "Standard_A2"
$clientUserPw = ConvertTo-SecureString "1234%%abcd" -AsPlainText -Force
$clientCred = New-Object -TypeName pscredential ùArgumentList "sampleCorpAdmin", $clientUserPw 
$OSDiskNameSql = $VMNameSql + "OSDisk"
$OSDiskNameIIS = $VMNameIIS + "OSDisk"

# Resource Group
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location

# Storage
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Type $StorageType -Location $Location

# Network SQL
$PIpSql = New-AzureRmPublicIpAddress -Name $InterfaceNameSql -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic
$SubnetConfigSql = New-AzureRmVirtualNetworkSubnetConfig -Name $Subnet1Name -AddressPrefix $VNetSubnetAddressPrefix
$VNetSql = New-AzureRmVirtualNetwork -Name $VNetNameSql -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $SubnetConfigSql
$InterfaceSql = New-AzureRmNetworkInterface -Name $InterfaceNameSql -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNetSql.Subnets[0].Id -PublicIpAddressId $PIpSql.Id

# Compute
## Setup sql VM object
$VirtualMachineSql = New-AzureRmVMConfig -VMName $VMNameSql -VMSize $VMSize
$VirtualMachineSql = Set-AzureRmVMOperatingSystem -VM $VirtualMachineSql -Windows -ComputerName $ComputerNameSql -Credential $clientCred -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachineSql = Set-AzureRmVMSourceImage -VM $VirtualMachineSql -PublisherName MicrosoftSQLServer -Offer SQL2017-WS2016 -Skus Standard -Version "latest"
$VirtualMachineSql = Add-AzureRmVMNetworkInterface -VM $VirtualMachineSql -Id $InterfaceSql.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskNameSql + ".vhd"
$VirtualMachineSql = Set-AzureRmVMOSDisk -VM $VirtualMachineSql -Name $OSDiskNameSql -VhdUri $OSDiskUri -CreateOption FromImage

## Create the VM in Azure
$vmSQL = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachineSql

#Network IIS
$PIpIIS = New-AzureRmPublicIpAddress -Name $InterfaceNameIIS -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic
$SubnetConfigIIS = New-AzureRmVirtualNetworkSubnetConfig -Name $Subnet1Name -AddressPrefix $VNetSubnetAddressPrefix
$VNetIIS = New-AzureRmVirtualNetwork -Name $VNetNameIIS -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $SubnetConfigIIS
$InterfaceIIS = New-AzureRmNetworkInterface -Name $InterfaceNameIIS -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNetIIS.Subnets[0].Id -PublicIpAddressId $PIpIIS.Id

# Compute
## Setup sql VM object
$VirtualMachineIIS = New-AzureRmVMConfig -VMName $VMNameIIS -VMSize $VMSize
$VirtualMachineIIS = Set-AzureRmVMOperatingSystem -VM $VirtualMachineIIS -Windows -ComputerName $ComputerNameIIS -Credential $clientCred -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachineIIS = Set-AzureRmVMSourceImage -VM $VirtualMachineIIS -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version "latest"
$VirtualMachineIIS = Add-AzureRmVMNetworkInterface -VM $VirtualMachineIIS -Id $InterfaceIIS.Id
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskNameIIS + ".vhd"
$VirtualMachineIIS = Set-AzureRmVMOSDisk -VM $VirtualMachineIIS -Name $OSDiskNameSql -VhdUri $OSDiskUri -CreateOption FromImage

## Create the VM in Azure
$vmIIS = New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachineIIS

#Remove-AzureRmResourceGroup -Name $ResourceGroupName -Force