# ``android-licenses-windows``

Automatic Android SDK package license acceptance for Windows, because it's
a chore and life is too short to do it manually.

Should work with Windows Vista and up.

## Installation

Get [the script](./androidl.cmd), run it, voilà. No dependencies required
whatsoever.

## Usage

```
Usage: androidl [-h] [--unattended] [--version]
    Accepts licenses for all available packages of Android SDK.

    Optional arguments:
      -h, --help, -?    show this help message and exit
      --unattended, -u  run this script unattended (don't halt)
      --version         output version information and exit

    Exit status:
      0                 successful program execution
      1                 this dialog was displayed
      2                 unrecognized argument combination
      3                 sdkmanager discovery failed
      4                 sdkmanager execution failed
```

## Alternatives

Assuming `sdkmanager` is in your PATH and you have [WSL][1] installed and
configured, the following one-liner should work with every default distro:

```batchfile
wsl --exec yes "y" | sdkmanager --licenses
```

Note that `yes` isn't guaranteed to output `y`, hence the additional argument.

## Rationale

The moment I attempt to do anything involving `Android\Sdk`, everything
spontaneously explodes. Now it won't have to.

*don't ask*

## License

MIT. See [LICENSE](./LICENSE).

[1]: https://docs.microsoft.com/en-us/windows/wsl/about
