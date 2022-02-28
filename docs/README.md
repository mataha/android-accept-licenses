# ``android-accept-licenses``

[![Project Status: Inactive – The project has reached a stable, usable state but is no longer being actively developed; support/maintenance will be provided as time allows.](https://www.repostatus.org/badges/latest/inactive.svg)](https://www.repostatus.org/#inactive)

Automatic Android SDK package license acceptance for Windows, because it's
a chore and life is too short to do it manually.

Should work with Windows Vista and up.

## Installation

Get [the script](../src/androidl.cmd), run it, voilà. No dependencies required
whatsoever.

## Usage

```
Usage: androidl [-h] [-u] [--version]
    Accepts licenses for all available packages of Android SDK.

    Optional arguments:
      -h, --help        show this help message and exit
      -u, --unattended  run this script unattended (don't halt)
      --version         output version information and exit

    Exit status:
      0                 successful program execution
      1                 this dialog was displayed
      2                 incorrect command line usage
      3                 sdkmanager discovery failed
      4                 sdkmanager execution failed
```

## Alternatives

All of the below require `sdkmanager` to be in your PATH.

### Using WSL

With [WSL][1] installed and configured, the following one-liner should work on
every default distribution:

```batchfile
wsl --exec yes "y" | sdkmanager --licenses
```

### Using Git Bash

[Git for Windows][2] provides a bash emulation that, assuming it's installed
and configured to be in your PATH, can be used with the following one-liner:

```batchfile
bash -c "yes 'y' | sdkmanager --licenses"
```

*Note that `yes` isn't guaranteed to output `y`, hence the additional argument.*

## Rationale

The moment I attempt to do anything involving `Android\Sdk`, everything
spontaneously explodes. Now it won't have to.

*don't ask*

## License

MIT. See [LICENSE](../LICENSE).

[1]: https://docs.microsoft.com/en-us/windows/wsl/about
[2]: https://gitforwindows.org/
