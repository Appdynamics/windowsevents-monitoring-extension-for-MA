param ($Config, $LastRun, $Logs, $EventIDs)

#Gather the events run since the last run
$Events = $Logs | foreach { Get-EventLog -LogName $_ -After $LastRun -InstanceId $EventIDs -ErrorAction SilentlyContinue  } | Sort-Object TimeGenerated -Descending

$EventList = @()
#Loop through Windows events and configured event monitors to build request
foreach ($Event in $Events) {
    foreach ($EventMonitor in $Config.events) {
        if ($EventMonitor.aggregate | Where-Object {$_.id -eq $Event.InstanceId}){
            $Type = "$($Event.EntryType)"
            $EventList += @{
                ID = $Event.InstanceId
                Type = $Type
                Message = $Event.Message
                Source = $Event.Source
                Monitor = $EventMonitor
            }
        }
    }
}

$EventList