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

Unfortunately, the script lacks the ability to look at the VM's screen when the commands finish. To compensate this, a second command is (mostly) appended to the main commands. The shell (zsh in the Arch Linux Live ISO) executes a second command when the main command has finished. The second command is curl requesting a web like http://vboxhost:8080/vmstatus/CURRENTVM/step/*stepnumber*/returncode/*returncode*. The script's internal web server receives the HTTP request and therefore "knows" the returncode of the specified step number.
The script waits for completion of one step before it transfers the next command to the virtual machine.

Additionally, a while loop inside the VM starts a curl command every few seconds in the background, so the script assumes the virtual machine is still running. So far, the "I'm alive" messages are just shown by the script, nothing else happens.

Before anything is changed on the virtual machine's hard disk, the script ensures there are no partitions present.

For a very first try of the tiny web server, see `./webserver-thread-test.pl`.


Instructions
============

1. Download ArchLinux Live ISO image from the official mirrors

2. Create a virtual machine using the VirtualBox Manager (type=Linux, Version=Arch Linux (64 bit), 256 MB RAM, new dynamic VDI with 8 GB of size)

3. Start the virtual machine using the downloaded ISO image as CD

4. Hit Enter in the start screen ("Boot Arch Linux (x86_64)")

5. Wait for the shell prompt ("root@archiso ~ #")

6. Run `ip route` inside your virtual machine, remember the IP address ("default via x.x.x.x")

7. Reboot VM and wait until the start screen ("Boot Arch Linux (x86_64)") appears, but don't hit Enter

8. Run `vboxmanage list vms` on your host, remember the UUID ("{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}")

9. Create config file `install-archlinux-inside-vm.yml` (use template `install-archlinux-inside-vm.yml.sample`)

10. Modify `./install-archlinux-inside-vm.yml`:
   - change UUID (parameter vm_id)

11. Modify `./install-archlinux-inside-vm`:
   - change IP address of the VM host as seen by the virtual machine (mine was 10.0.2.2), see step 6
   - remove "{...export http_proxy='http://proxy:3128'...}," if you don't have a proxy with this name and port or adjust to fit your's (mine is squid)

12. Run `./install-archlinux-inside-vm ./install-archlinux-inside-vm.yml`


Future
======

- implement the TODOs
- implement command line options (using Getopt I think)
- automatic creation/boot/reboot/deletion of virtual machine
- moving instruction list to separate file(s)
- enhance internal webserver for providing status information
- support english keyboard as well


Requirements
============

The following packages are needed in order to run this script:

- perl-timedate
- perl-http-daemon
- perl-yaml-tiny


Config file
===========

The configuration file is specified as command line argument. See the sample file (`install-archlinux-inside-vm.yml.sample`).


Known issues
============

- maybe you have to adjust the delay_before values in `vm-steps.yml` if for example the VM hasn't finished booting but the script already continues sending keystrokes to the VM
- not every key stroke works so far (you'll get "Error: missing scancode for ...")
- the mkfs.ext4 command for the boot partition will prompt if there was such a partition before (beginning 2014-07-03, never seen this before)

  If you enter this situation, just enter **y** followed by the enter key.  
  Maybe the parameter `-F -F` (yes, twice) would force the creation of the filesystem (less secure of course).  
  This situation could be avoided if dd'ed from /dev/zero to the partition before deleting the partition.

  Example output from mkfs.ext4:  
  ```
  mke2fs 1.42.10 (18-May-2014)
  /dev/sda1 contains a ext4 file system labelled 'boot'
          last mounted on /mnt/boot on Mon Jun  9 13:30:10 2014
  Proceed anyway? (y,n)
  ```

