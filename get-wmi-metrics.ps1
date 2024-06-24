Write-Host "Script started."

function Cleanup-Resources
{
    param (
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.Runspaces.RunspacePool] $RunspacePool,

        [Parameter(Mandatory = $false)]
        [System.Collections.ObjectModel.Collection[PSObject]] $Jobs
    )


    # Clean up each job's PowerShell instance
    if ($Jobs)
    {
        foreach ($Job in $Jobs)
        {
            try
            {
                if ($Job.PowerShell)
                {
                    $Job.PowerShell.Dispose()
                }
            }
            catch
            {
                $errorMessage = "An error occurred: $_"
                Write-Host $errorMessage

            }

        }
    }

    # Close and dispose of the runspace pool
    try
    {
        if ($RunspacePool)
        {
            $RunspacePool.Close()
            $RunspacePool.Dispose()
        }
    }
    catch
    {
        $errorMessage = "An error occurred: $_"
        Write-Host $errorMessage

    }


}

function Check-Timeout
{
    $elapsedSeconds = ((Get-Date) - $ScriptStartTime).TotalSeconds
    if ($elapsedSeconds -gt $InternalTimeoutSecs)
    {
        $errorMessage = "Internal timeout of $InternalTimeoutSecs seconds reached."
        throw $errorMessage
    }
}

$ScriptStartTime = Get-Date
# Current Directory
$Location = Get-Location

$MonitorXmlPath = Join-Path -Path (Get-Location) -ChildPath "monitor.xml"
[xml]$MonitorXml = Get-Content -Path $MonitorXmlPath
$ExecutionTimeoutSecs = $MonitorXml.monitor.'monitor-run-task'.'execution-timeout-in-secs'
$ExecutionTimeoutSecs = [int]$ExecutionTimeoutSecs

# Slightly less than actual script execution timeout to ensure resources cleanup
$InternalTimeoutSecs = $ExecutionTimeoutSecs - 5


# Maximum number of concurrent runspaces
$MaxConcurrentRequests = 10

# Deserialized Config Json
$Config = Get-Content -Raw "$Location\config.json" | ConvertFrom-Json

# Unix Epoch
[datetime]$Epoch = '1970-01-01 00:00:00'

$FiveMinutesAgo = (Get-Date).AddMinutes(-5).Subtract($Epoch).TotalSeconds

# Validate the configuration
$requiredConfigProperties = @('EventLogPaths', 'EventIds', 'EventLogEntryTypes', 'EventLogMessageFilters', 'ExcludedEventIDs')
foreach ($prop in $requiredConfigProperties)
{
    if ($Config.$prop -isnot [array])
    {
        throw "config.json property '$prop' must be an array"
    }
}

# Determine if the monitor has run and set the "Last Run" time.
# Default to 5 minutes ago
if ($Config.lastRun -eq $null)
{
    $Config.lastRun = $FiveMinutesAgo
}
else
{
    $Config.lastRun = [math]::Max($Config.lastRun, $FiveMinutesAgo)
}

$LastRun = $Epoch.AddSeconds($Config.lastRun)

# Run through the list of configured events and gather a list of unique log names to query
$Logs = @()
$EventIDs = @()

$RunspacePool = $null
$Jobs = @()

try
{
    foreach ($EventLogPath in $Config.EventLogPaths)
    {
        if ($Logs -notcontains $EventLogPath -and [System.Diagnostics.EventLog]::Exists($EventLogPath))
        {
            $Logs += $EventLogPath
        }
    }

    foreach ($EventID in $Config.EventIDs)
    {
        if ($EventIDs -notcontains $EventID)
        {
            $EventIDs += $EventID
        }
    }

    # Gather the events run since the last run using the correct command available (PowerShell 5.x vs 7.x)
    $FoundEvents = @()
    if (Get-Command Get-EventLog -ErrorAction SilentlyContinue)
    {
        $FoundEvents = (&"$Location\get-winevent.ps1" -Config $Config -LastRun $LastRun -Logs $Logs -EventIDs $EventIDs)
        Check-Timeout
    }


    # Limit the number of events to the maximum set in the configuration
    $FoundEvents = $FoundEvents | Select-Object -First $Config.MaxEventsPerRun

    if ($FoundEvents.Count -gt 0)
    {
        $Token = (&"$Location\get-oauth-token.ps1" -ControllerUrl $Config.controllerURL -AccountName $Config.account -ApiClient $Config.apiClient -ApiSecret $Config.apiClientSecret)

        Check-Timeout

        # Create a runspace pool and throttle the number of runspaces
        $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrentRequests)
        $RunspacePool.Open()

        $ScriptBlock = {
            param ($FoundEvent, $Token, $Config)

            # Determine the severity based on the event type
            $Data = switch ($FoundEvent.Type)
            {
                "Error" {
                    "ERROR"
                }
                "Warning" {
                    "WARN"
                }
                Default {
                    "INFO"
                }
            }

            # Construct the message details
            $Msg = @(
                "Type:$( $FoundEvent.Type )",
                "Source:$( $FoundEvent.Source )",
                "EventID:$( $FoundEvent.ID )",
                "Machine:$( $Config.node )",
                "Message:$( $FoundEvent.Message )"
            )

            # URL encode the summary message
            $SummaryEncoded = [uri]::EscapeDataString($Msg -join "`n")

            # Construct the query string for the API call
            $QueryString = @(
                "severity=$Data",
                "summary=$SummaryEncoded",
                "eventtype=CUSTOM",
                "customeventtype=WindowsEventLogMonitor",
                "propertynames=EventId",
                "propertynames=Machine",
                "propertynames=Message",
                "propertyvalues=$([uri]::EscapeDataString($FoundEvent.ID) )",
                "propertyvalues=$([uri]::EscapeDataString($Config.node) )",
                "propertyvalues=$([uri]::EscapeDataString($FoundEvent.Message) )"
            ) -join '&'

            # Construct the full URI for the API call
            $Uri = "$( $Config.controllerURL )/controller/rest/applications/$( $Config.application )/events?$QueryString"

            # Set up the headers for the API call
            $Headers = @{
                "Authorization" = "Bearer $Token"
            }

            # Set the security protocol to TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            try
            {

                # Make API Call
                Invoke-RestMethod -Uri $Uri -Method POST -Headers $Headers -UseBasicParsing | Out-Null
            }
            catch
            {

                $errorMessage = "An error occurred during the API call: $_"
                Write-Host $errorMessage
            }
        }

        $Jobs = foreach ($FoundEvent in  $FoundEvents)
        {
            $Powershell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($FoundEvent).AddArgument($Token).AddArgument($Config)
            $Powershell.RunspacePool = $RunspacePool
            $AsyncResult = $Powershell.BeginInvoke()

            New-Object -TypeName PSObject -Property @{
                PowerShell = $Powershell
                AsyncResult = $AsyncResult
            }
            Check-Timeout
        }

        # Wait for all runspaces to complete
        foreach ($Job in $Jobs)
        {
            if ($null -ne $Job -and $null -ne $Job.PowerShell)
            {
                $Job.PowerShell.EndInvoke($Job.AsyncResult)
                $Job.PowerShell.Dispose()
            }
        }


        # Close the runspace pool
        $RunspacePool.Close()
        $RunspacePool.Dispose()
    }

}
finally
{
    Write-Host "Starting resource cleanup."
    Cleanup-Resources -RunspacePool $RunspacePool -Jobs $Jobs
}

# Write Timestamp to lastRun config property
$Config.lastRun = Get-Date -UFormat '%s'
$Config | ConvertTo-Json -Depth 100 | Out-File $Location"\config.json"
Write-Host "Script completed successfully."
