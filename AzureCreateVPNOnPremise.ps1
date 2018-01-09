install-module AzureRM 
import-module AzureRM
 
 
#### On Premise Network ####
Login-AzureRmAccount
Get-AzureRmSubscription
Select-AzureRmSubscription -SubscriptionName "Azure Pass"
 
$Location = "West Europe"
$VNetName = "VpnVnetOnPremise"
$ResourceGroupName = "OnPremiseResourceGroup"
 
#Only if neccessary
#$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix 10.11.0.0/27
 
$subnet1 = New-AzureRmVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix 10.11.0.0/27
$subnet2 = New-AzureRmVirtualNetworkSubnetConfig -Name 'Subnet1' -AddressPrefix 10.11.1.0/28
New-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix 10.11.0.0/16 -Subnet $subnet1, $subnet2

New-AzureRmLocalNetworkGateway -Name Site2 -ResourceGroupName $ResourceGroupName -Location $Location -GatewayIpAddress '52.169.141.165' -AddressPrefix '10.0.0.0/24'

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
$VNetName = "VpnVnetOnPremise"
$ResourceGroupName = "OnPremiseResourceGroup"
$InterfaceName = "Int07vpn"
$Location = "West Europe"
$vmName = "OnPremiseServer"
$VirtualMachine = Get-AzureRmVM -Name $vmName -ResourceGroupName $ResourceGroupName

$VNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName
$Interface = New-AzureRmNetworkInterface -Name $InterfaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[1].Id
Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $VirtualMachine