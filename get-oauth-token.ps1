param ([string] $ControllerUrl, [string] $AccountName, [string] $ApiClient, [string] $ApiSecret)

$Uri = "$($ControllerUrl)/controller/api/oauth/access_token"

$Headers = @{
    'Content-Type' = 'application/vnd.appd.cntrl+protobuf;v=1'
}

$Data = "grant_type=client_credentials&client_id=$($ApiClient)@$($AccountName)&client_secret=$($ApiSecret)"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
$Response = Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -Body $Data

$Response.access_token

} catch { 
}

