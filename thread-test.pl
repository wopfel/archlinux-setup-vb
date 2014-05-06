#!/usr/bin/perl

# Just a simple demo...

use threads;

sub http_thread {
    sleep 3;
    print "Done";
}


# No output buffering
$| = 1;

my $thread = threads->create( 'http_thread' );

print "1";
sleep 5;

$thread->join();

exit 0;

