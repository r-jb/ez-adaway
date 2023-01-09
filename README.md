# EZ AdAway

[EZ AdAway](https://github.com/r-jb/ez-adaway) is a Shell script that uses the hosts file in order to block ads system-wide.

-----

## Features

- **Easy to use**: run it directly in less than a minute.
- **No installation**: no install, no problem. This script can be run as an alias for minimal impact.
- **Lightweight**: this script is very small and has very few dependencies.

-----

## One-Liner run

Get started as fast as possible with minimal trouble using the following command:

### `curl -fsSL https://github.com/r-jb/ez-adaway/raw/main/adaway.sh | sh`

## Installation

It is recommended that you review the code before executing it.

### Method 1: Creating an alias

Add this line to your shell `.*rc` configuration file.
e.g: add this to your `.bashrc`, if your shell is `bash`:

```sh
alias adaway="$(curl -fsSL https://raw.githubusercontent.com/r-jb/ez-adaway/main/adaway.sh | sh)"
```

### Method 2: Download the script and run it

Using `wget`:

```sh
wget https://raw.githubusercontent.com/r-jb/ez-adaway/main/adaway.sh
chmod +x adaway.sh
./adaway.sh
```

Using `curl`:

```sh
curl -O https://raw.githubusercontent.com/r-jb/ez-adaway/main/adaway.sh
chmod +x adaway.sh
./adaway.sh
```

-----

## Usage

### Run the script

To bring up the script menu, just run:
`adaway`

The script can also be launched with command line arguments as follows:

- `adaway apply`: Activate the adblocker
- `adaway restore`: Deactivate the adblocker

### Change the blocking lists

By following  lists are used by default:

- [Steven Black Unified hosts](https://github.com/StevenBlack/hosts)
- [OISD](https://oisd.nl)

You can modify the blocking lists in the script by just changing the `HOST_SOURCES` variable at the beginning of the script. Comments in the list are ignored.

-----

## Uninstall

-----

## How the script works

-----

## Advantage of using this kind of AdBlocker

- **No performance loss**: this method uses native system components and eliminate the CPU overhead of a full on adblocker
- **Works system-wide**: the domain block works not only in browsers, but in every other program as well
- **Not browser a plugin**: not another one

-----

### Note

This script is in no way a a full replacement for advanced browser adblockers like [uBlock Origin](https://github.com/gorhill/uBlock).
