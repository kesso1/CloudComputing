import-module AzureRM
 
#### On Premise Network ####
$pass = ConvertTo-SecureString "YN5/u2KC0EwiwOoLGqiaGByHvB3DrFrlqKTSbAiAKw0=" -AsPlainText -Force
#Service Principal ID is defined in Azure Automation - Auszufuehrendes Konto
#Key is defined in Azure Active Directory - Automation - Keys
$cred = New-Object -TypeName pscredential -ArgumentList "95229bfc-64b4-479c-be59-668ee52e8553", $pass
Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId "38e69ad1-2007-434c-880e-4f9c1c98ac4b" -SubscriptionId "9bc20da0-8454-4a4e-ae08-ada2180eb46e"
$ResourceGroupName = "SampleCorp"
$Location = "NorthEurope"
$VNetName = "VpnVnetOnAzure"
 
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix 10.12.0.0/27
$subnet2 = New-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet1' -AddressPrefix 10.12.1.0/28
New-AzureRmVirtualNetwork -Name VpnVnetOnAzure -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix 10.12.0.0/16 -Subnet $subnet1, $subnet2

New-AzureRmLocalNetworkGateway -Name Site2 -ResourceGroupName $ResourceGroupName -Location $Location -GatewayIpAddress '52.166.12.144' -AddressPrefix '10.0.1.0/24'

#First Reserve IP address on both sites -> will be needed as gateway address 
$gwpip = New-AzureRmPublicIpAddress -Name gwpip -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic

$vnet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
$subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
$gwipconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name gwpip -SubnetId $subnet.Id -PublicIpAddressId $gwpip.Id

New-AzureRmVirtualNetworkGateway -Name VNet1GW -ResourceGroupName $ResourceGroupName -Location $Location -IpConfigurations $gwipconfig -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1

#Only to get the public ip (for config on premise network)
Get-AzureRmPublicIpAddress -Name gwpip -ResourceGroupName $ResourceGroupName
 
$gateway1 = Get-AzureRmVirtualNetworkGateway -Name VNet1GW -ResourceGroupName $ResourceGroupName
$local = Get-AzureRmLocalNetworkGateway -Name Site2 -ResourceGroupName $ResourceGroupName
 
New-AzureRmVirtualNetworkGatewayConnection -Name VNet1toSite2 -ResourceGroupName $ResourceGroupName -Location $Location -VirtualNetworkGateway1 $gateway1 -LocalNetworkGateway2 $local -ConnectionType IPsec -RoutingWeight 10 -SharedKey '1234%%abcd'
 
#Verify VPN connection
Get-AzureRmVirtualNetworkGatewayConnection -Name VNet1toSite2 -ResourceGroupName $ResourceGroupName

#Create additional VPN NIC's
$VNetName = "VpnVnetOnAzure"
$ResourceGroupName = "SampleCorp"
$InterfaceName = "Int07vpn"
$Location = "NorthEurope"
$vmName = "vm-2017dc"
$VirtualMachine = Get-AzureRmVM -Name $vmName -ResourceGroupName $ResourceGroupName

$VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
$Interface = New-AzureRmNetworkInterface -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[1].Id
Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $VirtualMachine