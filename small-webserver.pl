#!/usr/bin/perl

# Quelle: http://www.perlmonks.org/?node_id=303419

##############
# This file is just for testing purposes
##############


use HTTP::Daemon;
use threads;

my $webServer;

my $d = HTTP::Daemon->new(LocalAddr => $ARGV[0],
                          LocalPort => 8080,
                          Listen => 20) || die;

print "Web Server started!\n";
print "Server Address: ", $d->sockhost(), "\n";
print "Server Port: ", $d->sockport(), "\n";

print "Start.\n";

while (my $c = $d->accept) {
    threads->create(\&process_one_req, $c)->detach();
}

print "End.\n";

sub process_one_req {
    print "Processing request.\n";
    my $c = shift;
    my $r = $c->get_request;
    if ($r) {
        if ($r->method eq "GET") {
            my $path = $r->url->path();
            $c->send_file_response($path);
            #or do whatever you want here
        }
    }
    $c->close;
    undef($c);
}
