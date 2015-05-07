#!/usr/bin/env perl
# VM Signare - Control server
use Mojolicious::Lite;
use Mojo::JSON;

# Target branch for GitHub Webhook receiver
our $TARGET_BRANCH = 'master';

# ----

# Set configuration for hypnotoad daemon
app->config(
	hypnotoad => {
		listen => [ 'http://*:' . ( $ENV{PORT} || 80 ) ],
	},
);

# Initialize clients hash
our %clients = ();
# Initialize repository revision
our %stats = ();

# WebSocket endpoint for push notification to signage device
websocket '/notif' => sub {
	my $s = shift;

	# Set timeout sec
	$s->inactivity_timeout(600);

	# Insert connection into clients hash
	my $client_id = sprintf("%s", $s->tx);
	$clients{$client_id} = $s->tx;

	# Set event handler
	$s->on(json => sub { # Incomming message
		my ($tx, $hash) = @_;
		if (defined $hash->{cmd} && $hash->{cmd} eq 'get-latest-repo-rev') {
			$tx->send({ json => {
				cmd => $hash->{cmd},
				repo_rev => $stats{repo_rev} || undef,
			}});
		}
	});
	$s->on(finish => sub { # Closed
		my ($s, $code, $reason) = @_;
		delete $clients{$client_id};
	});

	return;
};

# GitHub Webhook receiver
any '/github-webhook-receiver' => sub {
	my $s = shift;

	# Read payload parameter
	my $data = $s->req->body;
	my $payload;
	eval {
		$payload = Mojo::JSON::decode_json($data);
	}; if ($@) {
		$s->render(text => 'Invalid payload format', status => 400);
		return;
	}

	# Check for branch name
	if ($TARGET_BRANCH ne "" && $payload->{ref} ne 'refs/heads/'.$TARGET_BRANCH){
		$s->render(text => 'Not target refs');
		return;
	}

	# Save revision
	$stats{repo_rev} = $payload->{after};

	# Notify to clients
	foreach my $client_id (keys %clients) {
		$clients{$client_id}->send({ json => {
			cmd => 'repository-updated',
		}});
	}

	$s->render(text => 'OK');
};

app->start;
