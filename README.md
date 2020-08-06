# xbar

`xbar` is a command line tool that mutates project configuration settings to be compatibile with Xcode 12 beta. Specifically, this adjusts some of the issues commonly found with projects built with Carthage.

## Usage

Running `xbar` in your root directory with no arguments will automatically inspect your `Carthage` folder, and update any checked out projects in there. This is highly useful for needing to rebuild dependencies that may have had issues when running in Xcode 12 beta.

Tentatively, there is support for passing in the `xcodeproj` paths for any additional projects you'd like to adjust. Cocoapods support is coming soon as well.

`xbar` will adjust the following keys inside each project that is given to it with the following values:

- `IPHONEOS_DEPLOYMENT_TARGET`: This will be adjusted to "11.0", which is the first iOS version that removed 32-bit support.
- `EXCLUDED_ARCHS`: This is a new setting introduced in Xcode 12 beta 3, which works opposite of `VALID_ARCHS` (now deprecated). As the name suggests, any architecture names included in here will be excluded from being built. The list of architectures can be found in this codebase.
- `VALID_ARCHS`: This is a now-deprecated setting, deprecated in Xcode 12 beta 3 and newer. This value will get set to "".

## What does `xbar` mean?

The name comes from the phrase "**X**code **B**eta **A**rchitecture **R**emover". 🙂
