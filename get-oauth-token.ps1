param ([string] $ControllerUrl, [string] $AccountName, [string] $ApiClient, [string] $ApiSecret)

$Uri = "$($ControllerUrl)/controller/api/oauth/access_token"
$Headers = @{ 'Content-Type' = 'application/x-www-form-urlencoded' }
$Data = "grant_type=client_credentials&client_id=$($ApiClient)@$($AccountName)&client_secret=$($ApiSecret)"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    $Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Data
    return $Response.access_token
} catch {
    Write-Host "[WindowsEvents] OAuth token fetch failed: $_"
    return $null
}
