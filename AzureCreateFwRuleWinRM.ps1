import-module AzureRM
$subscriptionIdEnterprise = "9bc20da0-8454-4a4e-ae08-ada2180eb46e"
$subscriptionIdProfessional = "7411621f-b90e-4c14-9a21-b9950e480d4f"

$pass = ConvertTo-SecureString "W80RJe8mqPuITJLt2qz/roEATJ9BxdCo8TSoxjSurWQ=" -AsPlainText -Force
$cred = New-Object -TypeName pscredential –ArgumentList "4b3273ca-d65c-47bc-979a-9fd70c03fc44", $pass 
Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId 38e69ad1-2007-434c-880e-4f9c1c98ac4b -SubscriptionId $subscriptionIdProfessional

$nsg = Get-AzureRmNetworkSecurityGroup -Name ottilabclient-nsg -ResourceGroupName ottilab
$nsg | Add-AzureRmNetworkSecurityRuleConfig -Name "AllowWinRM" -Description "AutoAllow WinRM" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 5985-5986 | Set-AzureRmNetworkSecurityGroup