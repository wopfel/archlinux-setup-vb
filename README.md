archlinux-setup-vb
==================

Automatically set up Arch Linux from an ISO image in a Virtualbox virtual machine.

When the virtual machine finished booting the Live CD, this script is taking over. After you started this script, it uses vboxmanage commands to send the necessary keystrokes to the running Arch Linux Live CD.

The main purpose is to prove that
- the ISO is fully functional
- Arch Linux can be installed from the Live CD
- the installed Arch Linux is bootable

THIS IS WORK IN PROGRESS!

Note: The virtual machine must be created manually at the moment.

See file `Virtualbox-ArchLinux-ISO-testen` for the vboxmanage commands emulating keystrokes so far. That file isn't used any longer. All commands from this file were migrated to the script.


Script
======

`install-archlinux-inside-vm`

When the virtual machine has finished booting from the Live CD and the shell prompt is ready,
you can run `./install-archlinux-inside-vm`.

The script emulates the keystrokes submitting all commands necessary for setting up an Arch Linux environment.

The return code of the commands is passed back to the script. For this, a tiny web server is running inside the script.
If the command has completed successfully, the next command is submitted.


Details
=======

The script has a list of commands that are needed to set up an Arch Linux machine (including syslinux boot loader and lvm residing on an encrypted partition). The commands are taken from https://wiki.archlinux.de/title/ArchLinux_mit_verschl%C3%BCsseltem_LVM_und_Systemd.

Several commands are necessary until the new Arch Linux machine is completely set up. The script emulates the keystrokes using VirtualBox' vboxmanage the same way as a human being would enter the commands manually.

Unfortunately, the script lacks the ability to look at the VM's screen when the commands finish. To accomplish this, a second command is (usually) appended to the main commands. The shell (zsh in the Arch Linux Live ISO) executes the second command when the main command has finished. The second command is curl which transmits the returncode. The curl command requests a web page from a web server. In this environment, the script provides a tiny embedded web server. The curl command requests a web page like http://vboxhost:8080/vmstatus/CURRENTVM/step/<stepnumber>/returncode/<returncode>. The embedded web server gets the HTTP request and therefore "knows" the returncode of the specified step number.
The script waits for completion of one step before it transfers the next command to the virtual machine.

Additionally, a while loop inside the VM starts a curl command every few seconds in the background, so the script assumes the virtual machine is still running. So far, the "I'm alive" messages are just shown by the script, nothing else happens.

Before anything is changed on the virtual machine's hard disk, the script ensures there are no partitions present.

For a very first try of the tiny web server, see `./webserver-thread-test.pl`.


Instructions
============

Download ArchLinux Live ISO image from the official mirrors

Create a virtual machine using the VirtualBox Manager (type=Linux, Version=Arch Linux (64 bit), 256 MB RAM, new dynamic VDI with 8 GB of size)

Start the virtual machine using the downloaded ISO image as CD

Hit enter in the start screen ("Boot Arch Linux (x86_64)")

Wait for the shell prompt ("root@archiso ~ #")

Run `ip route` inside your virtual machine, remember the IP address ("default via x.x.x.x")

Run `vboxmanage list vms` on your host, remember the UUID ("{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}")

Modify `./install-archlinux-inside-vm`:
- change UUID (mine was {f57aeae8-bc2c-47c3-9b65-f5822f8b47ef})
- change IP address (mine was 10.0.2.2)
- remove "{...export http_proxy='http://proxy:3128'...}," if you don't have a proxy with this name and port or adjust to fit your's (mine is squid)

Run `./install-archlinux-inside-vm`


Future
======

- implement the TODOs
- implement command line options (using Getopt I think)
- automatic creation/boot/reboot/deletion of virtual machine
- moving instruction list to separate file(s)
- enhance internal webserver for providing status information
- support english keyboard as well


Known issues
============

- not every key stroke works so far (you'll get "Error: missing scancode for ...")
- the mkfs.ext4 command for the boot partition will prompt if there was such a partition before (beginning 2014-07-03, never seen this before)
  if you enter this situation, just enter y followed by the enter key
  maybe the parameter "-F -F" (yes, twice) forces the creation of the filesystem (less secure of course)
  this situation could be avoided if dd'ed from /dev/zero to the partition before deletion
  Example output from mkfs.ext4:
  mke2fs 1.42.10 (18-May-2014)
  /dev/sda1 contains a ext4 file system labelled 'boot'
          last mounted on /mnt/boot on Mon Jun  9 13:30:10 2014
  Proceed anyway? (y,n)

