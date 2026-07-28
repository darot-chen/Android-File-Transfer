# Architecture

``` text
SwiftUI -> ViewModel -> Services -> ADB Wrapper -> adb
```

## Services

-   DeviceService
-   ADBService
-   FileSystemService
-   TransferService
-   LoggerService

Use MVVM, async/await, dependency injection, protocol-oriented design.
