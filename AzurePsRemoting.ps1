Enable-PSRemoting -Force
#Accessing client configuration
#winrm s winrm/config/client '@{TrustedHosts="ottilabclient.northeurope.cloudapp.azure.com"}'
Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*'