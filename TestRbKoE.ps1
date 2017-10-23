write-host "Test KoE"

# $uri = "https://login.microsoftonline.com/38e69ad1-2007-434c-880e-4f9c1c98ac4b/oauth2/token?api-version=1.0"
# $body = "grant_type=client_credentials&resource=https%3A%2F%2Fmanagement.core.windows.net%2F&client_id=3c58ef7b-3e46-4c98-9664-b9da1dc37082&client_secret=o1QcHmHAKCIFe1GhXwnZBgkIdNSGGzq0fYpD3YHdvHM="
# $headers = @{"content-type"="application/x-www-form-urlencoded"}
# $result = Invoke-WebRequest -Uri $uri -Body $body -Headers $headers -Method "POST"

$result = "HalloWelt"
$result
#import-module AzureRM

$pass = ConvertTo-SecureString "W80RJe8mqPuITJLt2qz/roEATJ9BxdCo8TSoxjSurWQ=" -AsPlainText -Force
$cred = New-Object -TypeName pscredential –ArgumentList "4b3273ca-d65c-47bc-979a-9fd70c03fc44", $pass 
Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId 38e69ad1-2007-434c-880e-4f9c1c98ac4b -SubscriptionId 9bc20da0-8454-4a4e-ae08-ada2180eb46e
