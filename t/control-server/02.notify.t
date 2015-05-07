# Control-server - Test for Notifier to signage-device
use FindBin;
use Test::More;
use Test::Mojo;

# Load an Mojolicious::Lite app for testing
require "$FindBin::Bin/../../control-server.pl";
my $t = Test::Mojo->new;

# Correct request - Repository revision is still empty
$t->websocket_ok('/notif')->send_ok({json => {
    cmd => 'get-latest-repo-rev',
}})->message_ok->json_is('/repo_rev' => undef);

# Done
done_testing();
