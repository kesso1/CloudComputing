Enable-PSRemoting -Force
#On Client who access
winrm s winrm/config/client '@{TrustedHosts="ottilabclient.northeurope.cloudapp.azure.com"}'