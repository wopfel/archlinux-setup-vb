#!/usr/bin/perl

# Copyright (C) 2014 Bernd Arnold
# Licensed under GPLv2
# See file LICENSE for more information
#
# https://github.com/wopfel/archlinux-setup-vb

use strict;
use warnings;
use threads;
use HTTP::Daemon;
use HTTP::Status qw(:constants);
use utf8;



# Works with a german keyboard

my %scanmap;

#
# Base keys (without shift modifier key)
#

my $basemap = '
0x02::1234567890ß´
0x10::qwertzuiopü+
0x1e::asdfghjklöä#
0x2b::<yxcvbnm,.-';

for ( split /\n/, $basemap ) {

    if ( /^0x(..)::(.*)$/ ) {
        my $offset = $1;
        my $keys = $2;
        my $nr = 0;
        for my $key ( split //, $keys ) {
            #print "[ $key ]";
            $scanmap{ $key } = sprintf "%02x %02x", (hex($offset) + $nr), (hex($offset) + $nr + 128);
            $nr++;
        }
    }
}


#
# "Uppercase" keys (with shift modifier key)
#

my $uppermap = q,
0x02::!"§$%&/()=?`
0x10::QWERTZUIOPÜ*
0x1e::ASDFGHJKLÖÄ'
0x2b::>YXCVBNM;:_,;

for ( split /\n/, $uppermap ) {

    if ( /^0x(..)::(.*)$/ ) {
        my $offset = $1;
        my $keys = $2;
        my $nr = 0;
        for my $key ( split //, $keys ) {
            #print "[ $key ]";
            $scanmap{ $key } = sprintf "2a %02x %02x aa", (hex($offset) + $nr), (hex($offset) + $nr + 128);
            $nr++;
        }
    }
}

# Credits to: http://www.marjorie.de/ps2/scancode-set1.htm
$scanmap{ "<LT>" }       = "56 d6";
$scanmap{ "<GT>" }       = "2a 56 d6 aa";
$scanmap{ "<SPACE>" }    = "39 b9";
$scanmap{ " " }          = $scanmap{ "<SPACE>" };
$scanmap{ "<ENTER>" }    = "1c 9c";
$scanmap{ "<ARROW-DOWN>" }    = "e0 50 e0 d0";
$scanmap{ "<ARROW-LEFT>" }    = "e0 4b e0 cb";
$scanmap{ "<ARROW-UP>" }      = "e0 48 e0 c8";
$scanmap{ "<ARROW-RIGHT>" }   = "e0 4d e0 cd";


sub send_keys_to_vm {

    # You can run `showkey --scancodes` on a console to view the scancodes

    my $string = shift;
    my @scancodes = ();

    while ( length $string > 0 ) {

        # First part: <SPECIAL> keys
        # Second part: default keys, like 'q', 'w', ..., 'Q', ...
        if ( $string =~ /^(<.*?>)(.*)$/ ) {
            my $key = $1;
            $string = $2;

            if ( defined $scanmap{ $1 } ) {
                push @scancodes, $scanmap{ $1 };
            } else {
                print STDERR "Error: missing scancode for special '$key'!";
                die;
            }
            #print "=== $1 ===\n";
            #print "=== $2 ===\n";
        } elsif ( $string =~ /^(.)(.*)$/ ) {
            my $key = $1;
            $string = $2;
            #print "=== $1 ===\n";
            #print "=== $2 ===\n";
            if ( $key =~ /^(<|>)$/ ) {
                print STDERR "Error: Lonely '$key' found. Use <LT> and <GT> for single '<'/'>' keys!";
                die;
            }
            if ( defined $scanmap{ $1 } ) {
                push @scancodes, $scanmap{ $1 };
            } else {
                print STDERR "Error: missing scancode for key '$key'!";
                die;
            }
        }
        #print "==========\n";
    }


    # The command mustn't be too long, otherwise vboxmanage complains with the following message:
    # error: Could not send all scan codes to the virtual keyboard (VERR_PDM_NO_QUEUE_ITEMS)
    # To avoid this the scancodes are split and passed in several vboxmanage commands

    # While there are elements in the array...
    while ( scalar @scancodes > 0 ) {

        # Get the first 10 scancodes (note: in this context, one scancode could be "26 a6")
        my @subset = splice( @scancodes, 0, 10 );

        # Join all 2-digit scancodes using a blank (" ")
        my $scancodes = join " ", @subset;

        # Call vboxmanage
        # Blanks are not allowed, so the joined $scancodes doesn't work, vboxmanage complains with "Error: '...' is not a hex byte!"
        my @args = ( "vboxmanage", "controlvm", "{f57aeae8-bc2c-47c3-9b65-f5822f8b47ef}",
                     "keyboardputscancode",
                     split( / /, $scancodes )
                   );

        #print @args;
        system( @args ) == 0  or  die "Error: system call (@args) failed";

    }

}



sub process_client_request {

    print "Processing request.\n";

    my $c = shift;
    my $r = $c->get_request;

    if ($r) {
        print "URI: ", $r->uri->path, "\n";
        print "URL: ", $r->url->path, "\n";

        # /vmstatus/CURRENTVM/alive
        if ( $r->method eq "GET"  and  $r->url->path =~ m"^/vmstatus/CURRENTVM/alive$" ) {
            # Maybe we're handling more than one VM at the same time, so CURRENTVM is for future enhancements
            print "VM is alive!\n";
            # Send back status code 200: OK
            $c->send_status_line( 200 );
        } elsif ( $r->method eq "GET"  and  $r->url->path =~ m"^/vmstatus/CURRENTVM/lastcommandrc/(\d+)$" ) {
            # Maybe we're handling more than one VM at the same time, so CURRENTVM is for future enhancements
            print "VM reported return code: $1.\n";
            # Send back status code 200: OK
            $c->send_status_line( 200 );
        } else {
            $c->send_error( 501, "Too early. Function not implemented yet." );
        }
        #if ($r->method eq "GET") {
        #    my $path = $r->url->path();
        #    $c->send_file_response($path);
        #    #or do whatever you want here
        #}
    } else {
        $c->send_error( HTTP_FORBIDDEN );
    }

    $c->close;
    undef( $c );

}


sub http_thread {

    my $daemon = HTTP::Daemon->new(
                                    LocalPort => 8080,
                                    Listen => 20
                                  );

    print "Embedded web server started.\n";
    print "Server address: ", $daemon->sockhost(), "\n";
    print "Server port: ",    $daemon->sockport(), "\n";

    # Wait for client requests
    while ( my $c = $daemon->accept ) {
        threads->create( \&process_client_request, $c )->detach();
    }

    # TODO: Reach this point the "normal" way (how to exit the previous while loop?)

    print "Embedded web server ends.\n";

}


# No output buffering
$| = 1;

my $thread = threads->create( 'http_thread' );

print "Program started.\n";

send_keys_to_vm( "loadkezs deßlatin1<ENTER>" );

send_keys_to_vm( "uptime<ENTER>" );

send_keys_to_vm( "curl http://10.0.2.2:8080/vmstatus/CURRENTVM/alive<ENTER>" );

send_keys_to_vm( "cfdisk /dev/sda" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );
send_keys_to_vm( "<ENTER>" );                      # New partition
send_keys_to_vm( "<ENTER>" );                      # Primary
send_keys_to_vm( "100<ENTER>" );                   # MB
send_keys_to_vm( "<ENTER>" );                      # Beginning
send_keys_to_vm( "<ENTER>" );                      # Bootable
send_keys_to_vm( "<ARROW-DOWN>" );                 # Free space
send_keys_to_vm( "<ENTER>" );                      # New partition
send_keys_to_vm( "<ENTER>" );                      # Primary
send_keys_to_vm( "<ENTER>" );                      # Default size
send_keys_to_vm( "<ARROW-LEFT>" );                 # Highlight Write
send_keys_to_vm( "<ENTER>" );                      # Write
send_keys_to_vm( "yes<ENTER>" );
send_keys_to_vm( "<ARROW-LEFT><ARROW-LEFT>" );     # Highlight Units
send_keys_to_vm( "<ARROW-LEFT><ARROW-LEFT>" );     # Highlight Quit
send_keys_to_vm( "<ENTER>" );                      # Quit

send_keys_to_vm( "cryptsetup -c aes-xts-plain64 -y -s 512 luksFormat /dev/sda2" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );
send_keys_to_vm( "YES<ENTER>" );
send_keys_to_vm( "arch<ENTER>" );                  # The passphrase
send_keys_to_vm( "arch<ENTER>" );                  # Verify the passphrase

send_keys_to_vm( "cryptsetup luksOpen /dev/sda2 lvm" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );
send_keys_to_vm( "arch<ENTER>" );                  # The passphrase

send_keys_to_vm( "pvcreate /dev/mapper/lvm" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "vgcreate main /dev/mapper/lvm" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "lvcreate -L 2GB -n root main" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "lvcreate -L 2GB -n swap main" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "lvcreate -L 2GB -n home main" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "lvs" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mkfs.ext4 -L root /dev/mapper/main-root" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mkfs.ext4 -L home /dev/mapper/main-home" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mkfs.ext4 -L boot /dev/sda1" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mkswap -L swap /dev/mapper/main-swap" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mount /dev/mapper/main-root /mnt" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mkdir /mnt/home" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mount /dev/mapper/main-home /mnt/home" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mkdir /mnt/boot" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "mount /dev/sda1 /mnt/boot" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );

send_keys_to_vm( "pacstrap /mnt base base-devel syslinux" );
send_keys_to_vm( " ; curl http://10.0.2.2:8080/vmstatus/CURRENTVM/lastcommandrc/\$?<ENTER>" );


sleep 60;

threads->exit();

exit 0;

