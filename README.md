# Bootstrap
This repository bootstraps a GNU/Linux environment from a fresh installation. It will set up an SSH server with a static IP placing _my_ SSH keys into the root user's `.ssh` folder. If you run this script unmodified by following the instructions exactly below you may end up granting **me** root access to your machines, which is likely not your intention. If you like this script, fork this repository and replace the `authorized_keys` file with your **public** SSH keys and change the `GIT_LOC` bash variable in `bootstrap.sh` to your repository's location. Then download the script and run it from your repository.

The purpose of this is to allow me to quickly put a machine online in an accessible manner before provisioning it. This is mainly targeted at fresh Debian installations.

### Features
* Removes CD sources from `/etc/apt/sources.list`
* Updates repository information and installs all patches
* Installs git and clones this repository to download SSH keys
* Installs SSH keys for root access
* Sets a static IP (optional)
* Configures new hostname (optional)
* Prompts to restart if a new hostname is set

### Quick Start
1. Download the bootstrap script from the repository

    `wget https://git.krislamo.org/kris/bootstrap/raw/branch/main/bootstrap.sh`

2. Check that the file contains what you expected to download

    `less bootstrap.sh`

2. Run the script with root permissions

    `sudo bash bootstrap.sh`

_Note: you may prevent setting a new hostname or static IP by leaving those fields blank when requested._


### License
Bootstrap is licensed under 0BSD, a public domain equivalent license; see the `LICENSE` file for more information
