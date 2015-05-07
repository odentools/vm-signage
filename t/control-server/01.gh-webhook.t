# Control-server - Test for GitHub webhook receiver
use FindBin;
use Test::More;
use Test::Mojo;

# Load an Mojolicious::Lite app for testing
require "$FindBin::Bin/../../control-server.pl";
my $t = Test::Mojo->new;

# Correct request
my $dummy_rev = '6bae3181ce39075cc70b5abdbdf690cb2380f002';
$t->post_ok('/github-webhook-receiver' => json => {
    ref => 'refs/heads/master',
    after => $dummy_rev,
})->status_is(200)->content_like(qr/^OK$/);

# Different ref
$t->post_ok('/github-webhook-receiver' => json => {
    ref => 'refs/heads/foo',
})->status_is(200)->content_like(qr/Not target refs/);

# Empty payload
$t->post_ok('/github-webhook-receiver')->status_is(400);

# Done
done_testing();
