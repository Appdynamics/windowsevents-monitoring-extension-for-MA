param ($Config, $LastRun, $Logs, $EventIDs)


$EventSources = $Config.EventSources
$EventLogEntryTypes = $Config.EventLogEntryTypes
$EventLogMessageFilters = $Config.EventLogMessageFilters
$ExcludedEventIDs = $Config.ExcludedEventIDs


$ExcludedEventIDs = $Config.ExcludedEventIDs

$EntryTypeMap = @{
    "Error" = 2
    "Warning" = 3
    "Information" = 4
    "SuccessAudit" = 0
    "FailureAudit" = 0
}

$NumericEntryTypes = if ($EventLogEntryTypes)
{
    $EventLogEntryTypes.ForEach({ $EntryTypeMap[$_] })
}
else
{
    $EntryTypeMap.Values
}

$EventIDChunks = if ($EventIDs)
{
    $chunks = [System.Collections.Generic.List[object]]::new()
    $ChunkSize = 15
    for ($i = 0; $i -lt $EventIDs.Count; $i += $ChunkSize) {
        $chunks.Add($EventIDs[$i..([Math]::Min($i + $ChunkSize - 1, $EventIDs.Count - 1))])
    }
    $chunks
}
else
{
    ,@($null)
}

$StartTime = $LastRun

$EventList = [System.Collections.Generic.List[object]]::new()

foreach ($EventLogPath in $Logs)
{
    foreach ($Chunk in $EventIDChunks)
    {
        $QueryHash = @{
            LogName = $EventLogPath
            StartTime = $StartTime
        }

        if ($Chunk)
        {
            $QueryHash.ID = $Chunk
        }

        if ($EventSources)
        {
            $QueryHash.ProviderName = $EventSources
        }

        $Events = Get-WinEvent -FilterHashtable $QueryHash -ErrorAction SilentlyContinue

        foreach ($Event in $Events)
        {
            if (($NumericEntryTypes -contains $Event.Level -or -not $EventLogEntryTypes) -and
                    ($EventLogMessageFilters.Count -eq 0 -or $EventLogMessageFilters.Any({ $Event.Message -like "*$_*" })) -and
                    -not ($ExcludedEventIDs -contains $Event.Id))
            {

                $EventList.Add(@{
                    ID = $Event.Id
                    Type = $Event.LevelDisplayName
                    Message = $Event.Message
                    Source = $Event.ProviderName
                })
            }
        }
    }
}

$EventList.ToArray()
