#!/usr/bin/perl

# Copyright (C) 2014 Bernd Arnold
# Licensed under GPLv2
# See file LICENSE for more information
#
# https://github.com/wopfel/archlinux-setup-vb

use threads;
use HTTP::Daemon;


sub process_client_request {

    print "Processing request.\n";

    my $c = shift;
    my $r = $c->get_request;

    if ($r) {
        print "URI: ", $r->uri->path, "\n";
        print "URL: ", $r->url->path, "\n";
        #if ($r->method eq "GET") {
        #    my $path = $r->url->path();
        #    $c->send_file_response($path);
        #    #or do whatever you want here
        #}
    } else {
        $c->send_error( RC_FORBIDDEN );
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
sleep 60;

threads->exit();

exit 0;

