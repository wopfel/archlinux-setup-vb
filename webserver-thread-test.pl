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
$scanmap{ "<LT>" }       = "2b ab";
$scanmap{ "<GT>" }       = "2a 2b ab aa";
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

sleep 60;

threads->exit();

exit 0;

