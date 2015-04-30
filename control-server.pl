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

# WebSocket endpoint for push notification to signage device
websocket '/notif' => sub {
	my $s = shift;

	# Set timeout sec
	$s->inactivity_timeout(600);

	# Insert connection into clients hash
	my $client_id = sprintf("%s", $s->tx);
	$clients{$client_id} = $s->tx;

	# Set event handler
	$s->on(message => sub { # Incomming message
		my ($s, $message) = @_;
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

	# Notify to clients
	my $message = Mojo::JSON::encode_json({
		cmd => 'repository-updated',
	});
	foreach my $client_id (keys %clients) {
		$clients{$client_id}->send_message($message);
	}

	$s->render(text => 'OK');
};

app->start;
