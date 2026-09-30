# Security

This program reads your copy of Urban Pirate (`data.win` and its music files) and writes saves,
savestates and settings to `%LOCALAPPDATA%\gmrecomp\Urban_Pirate\`. It opens no network
connections and handles no credentials.

`data.win` is parsed as untrusted input by the recompiler (Python). A malformed file should
make it fail, never run anything.

To report a problem privately, use GitHub's "Report a vulnerability" on this repository.
