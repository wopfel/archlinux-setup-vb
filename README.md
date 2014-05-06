archlinux-setup-vb
==================

Setup an ArchLinux installation from an ISO image in a Virtualbox virtual machine

The virtual machine must be set up manually. When the virtual machine finished booting the Live CD,
the vboxmanage command is used to send key strokes to the running Arch Linux.

THIS IS WORK IN PROGRESS!

See file `Virtualbox-ArchLinux-ISO-testen` for the commands so far.

Planned:
A simple script that fires the key strokes to the virtual machine and 
that receives feedback from the virtual machine.

The feedback comes directly from the virtual machine using curl commands.
Example: curl http://vbhost:8080/vmstatus/step_7_finished/returncode_0

For this, a tiny web server is running inside the script (see `./webserver-thread-test.pl`
for a first example).
