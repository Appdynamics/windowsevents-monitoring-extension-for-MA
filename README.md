# Windows Events Monitoring Extension

The Windows Events Monitoring Extension allows the Machine Agent to gather events from Windows machines.

## Contents

The contents of this repository should be placed within the `/monitors` directory of the Machine Agent. The `config.json` file contains a sample configuration detailing how to configure the extension to connect to your controller and specify which event IDs to collect.

## Prerequisites

- AppDynamics Machine Agent
- PowerShell 5.x or 7.x installed

## Installation

1. Download the ZIP file of the "windowsevents-monitoring-extension-for-MA" repository from the repository's main page on GitHub.
2. Unzip the downloaded file and move the extracted folder into  the `/monitors` directory of the Machine Agent.
3. Configure the extension by modifying the config.json file present inside the extracted folder.
4. Restart the Machine Agent.

## Upgrade

1. Replace the existing files with the new ones in the appropriate subfolder within the `/monitors` directory of the Machine Agent.
2. Restart the Machine Agent.

## Creating an API Client

Before configuring the extension, you need to create an API client in the AppDynamics Controller with the appropriate permissions.

1. Log in to your AppDynamics Controller.
2. Navigate to Settings -> Administration -> API Clients.
3. Click Create API Client.
4. Enter a name for the API client, such as WindowsEventsMonitorClient.
5. Generate and securely store the API client secret. You will not be able to retrieve it later.
6. Assign the necessary roles or permissions to the API client. At a minimum, the client will need read access to the relevant application and write access to custom metrics.
7. Save the API client.

## Configuration

The `config.json` file is used to configure the Windows Events Monitoring Extension. The following settings are available:

- `lastRun`: Used internally to track the last run time. Initially set to `null`. Example: `"lastRun": 1617184000`
- `controllerURL`: The URL of the AppDynamics controller. Example: `"controllerURL": "http://appdynamics-controller.example.com:8090"`
- `account`: Your AppDynamics account name. Example: `"account": "customer1"`
- `apiClient`: The API client name for authentication. Example: `"apiClient": "testExtension"`
- `apiClientSecret`: The API client secret for authentication. Keep this confidential. Example: `"apiClientSecret": "************************************"`
- `application`: The application name in AppDynamics. Example: `"application": "Infrastructure-only"`
- `tier`: The tier name in AppDynamics. Example: `"tier": "InfrastructureOnly-Windows"`
- `node`: The node name in AppDynamics. Can be left empty. Example: `"node": "Node-01"`
- `EventLogPaths`: Array of Windows Event Log paths to monitor. This field cannot be left empty. Example: `"EventLogPaths": ["Application", "System", "Security"]`
- `EventSources`: Array of event sources to filter by. Leave empty for all sources. Example: `"EventSources": ["MyAppSource", "AnotherSource"]`
- `EventIds`: Array of event IDs to filter by. Leave empty for all IDs. Example: `"EventIds": [1000, 1001, 1002]`
- `EventLogEntryTypes`: Array of event log entry types to filter by. Leave empty if not needed. Example: `"EventLogEntryTypes": ["Error", "Warning"]`
- `EventLogMessageFilters`: Array of strings to filter event messages by. Leave empty if not needed. Example: `"EventLogMessageFilters": ["specific error", "certain warning"]`
- `ExcludedEventIDs`: Array of event IDs to exclude from monitoring. These event IDs will not be monitored. Example: `"ExcludedEventIDs": [5000, 5001]`
- `MaxEventsPerRun`: Maximum number of events to collect per run. Example: `"MaxEventsPerRun": 50`

## Custom Event Type

The extension reports the gathered Windows Event Logs to AppDynamics as custom events. These custom events will have the type `WindowsEventLogMonitor`. This allows you to easily filter and identify the events collected by this extension within the AppDynamics Controller.


## Release Notes

### 1.0.0

- Initial release.
- Support for gathering events by ID and Log.
- Allows filtering events in the controller by custom type 'WindowsEventLogMonitor' and custom property 'EventID'.
- Aggregates messages and other details into the description of the event.
- Support and tested for PowerShell 5.x and 7.x.

## Notice and Disclaimer

All Extensions published by AppDynamics are governed by the Apache License v2 and are excluded from the definition of covered software under any agreement between AppDynamics and the User governing AppDynamics Pro Edition, Test & Dev Edition, or any other Editions.
