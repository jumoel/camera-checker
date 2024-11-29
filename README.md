# camera-checker

Command line utility that logs JSON to stdout when any webcam turns on or off.

## Background

Originally built by @wouterdebie in https://github.com/wouterdebie/onair

## Usage

```
USAGE: camera-checker

OPTIONS:
  --ignore         (optional) Comma-separated list of cameras to ignore
  --debug          Enable additional debugging
  --help           Display available options
```

## Build

```
$ swift build -c release
$ cp .build/release/camera-checker ~/bin
```

## Setup

In case you happen to have a camera that is not detected correctly, use `--ignore` to ignore that specific camera.
