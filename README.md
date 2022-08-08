PI DISPLAY SLIDESHOW
====================

Raspberry PI slideshow for displaying posters on a portrait mode monitor. The posters should be available as a publicly readable Dropbox folder, provided as a download URL to the script.

### Version

The latest development version is 0.1.5 and the latest release is [0.1.4](https://github.com/grkvlt/pi-display-slideshow/releases/tag/release-0.1.4).

## Install

Download the install artifacts and extract the contents, then run the `install.sh` script as root. The target directory to install to shouyld be specified as the only argument to the script, as follows:

```
$ wget https://github.com/grkvlt/pi-display-slideshow/archive/refs/tags/release-0.1.4.tar.gz
...
$ tar zxvf release-0.1.4.tar.gz
pi-display-slideshow-release-0.1.4/
...
$ cd pi-display-slideshow-release-0.1.4
$ sudo ./install.sh /opt/slideshow
...
```

Installation can take several minutes, or longer on a slow connection or older Raspberry Pi.

### Configuration

Configure the Raspberry PI as follows:

* no screenblank
* ssh/vnc enabled

For best results, the display screen should be rotated 90 degrees into portrait mode, so that the aspect ratio more closely matches the posters to be displayed.

## Usage

Run the `slideshow.sh` script, which should be available on the users PATH after installation. You may need to re-login for this to take effect. If no arguments are provided, the `slideshow.ini` installed in the same directory as the script will be used, otherwise the first argument should point to a file with the configuration variables for the slideshow.

```
$ slideshow.sh portrait.ini
```

### Settings

The following variables can be set in the configuration file:

- **`DROPBOX_URL`** - _Dropbox download link for posters_
- **`SLIDESHOW_DIR`** - _Folder to save files into (defaults to `./slideshow`)_
- **`SLIDESHOW_LENGTH`** - _Slideshow length in minutes (defaults to 30)_
- **`SLIDESHOW_DELAY`** - _Delay between slides in seconds (defaults to 10)_
- **`SLIDESHOW_ROTATE`** - _Rotate posters for portrait mode? (default true)_
- **`SLIDESHOW_JOIN`** - _Join two posters with same prefix in landscape mode? (default false)_
- **`SCREEN_RES`** - _Hardcoded screen resolution as `XXXXxYYY`_

---
_Copyright 2022 by [Andrew Donald Kennedy](mailto:andrew.international@gmail.com) and Licensed under the [Apache Software License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)_