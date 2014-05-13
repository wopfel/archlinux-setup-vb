archlinux-setup-vb
==================

Set up an ArchLinux installation from an ISO image in a Virtualbox virtual machine.

The virtual machine must be created manually. When the virtual machine finished booting the Live CD,
the vboxmanage command is used to send key strokes to the running Arch Linux.

THIS IS WORK IN PROGRESS!

See file `Virtualbox-ArchLinux-ISO-testen` for the commands so far.


Script
======

`install-archlinux-inside-vm`
When the virtual machine has finished booting from the Live CD and the shell prompt is ready,
you can run `./install-archlinux-inside-vm`.

The script emulates the keystrokes submitting all commands necessary for setting up an ArchLinux environment.

The return code of the commands is passed back to the script. For this, a tiny web server is running inside the script.
If the command has completed successfully, the next command is submitted.


Details
=======

A while loop inside the VM starts a curl command every few seconds, so the script knows the virtual machine is still running.
So far, the "I'm alive" messages are just shown by the script, nothing else happens.

When the script transfers a command to the virtual machine, it (usually) appends a "; curl http://vboxhost:8080/vmstatus/CURRENTVM/step/<stepnumber>/returncode/<returncode>" in the shell. When the main command finishes, the shell (zsh in the ArchLinux Live ISO) executes the curl program which transfers the returncode of the previous command (the main command) using HTTP to the script. The script waits for completion before it transfers the next command to the cirtual machine.

For a very first try of the tiny web server, see `./webserver-thread-test.pl`.


Instructions
============

Download ArchLinux Live ISO image from the official mirrors

Create a virtual machine using the VirtualBox Manager (type=Linux, Version=Arch Linux (64 bit), 256 MB RAM, new dynamic VDI 8 GB)

Start the virtual machine using the downloaded ISO image as CD

Hit enter in the start screen ("Boot Arch Linux (x86_64)")

Wait for the shell prompt ("root@archiso ~ #")

Run `ip route` inside your virtual machine, remember the IP address ("default via x.x.x.x")

Run `vboxmanage list vms` on your host, remember the UUID ("{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}")

Modify `./install-archlinux-inside-vm`:
- change UUID (mine was {f57aeae8-bc2c-47c3-9b65-f5822f8b47ef})
- change IP address (mine was 10.0.2.2)

Run `./install-archlinux-inside-vm`


Future
======

- implement the TODOs
- implement command line options (using Getopt I think)
- automatic creation/deletion of virtual machine
- moving instruction list to separate file(s)
- use internal webserver for providing status information

