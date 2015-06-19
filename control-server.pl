#!/usr/bin/env perl
# VM Signare - Control server
use Mojolicious::Lite;
use Mojo::JSON;

# ----

# Initialize hash / array for WebSocket
our %deviceClients = (); # Key: Tx string, Value: Hash-ref
our %adminClients = (); # Key: Tx string, Value: Tx
our %adminWsKeys = (); # Key: Websocket auth key, Value: Generated date epoch-sec

# Initialize array of Id for processed queue
our @processed_queues_id = ();

# Initialize repository revision
our %repo_revs = ();

# Set configuration for hypnotoad daemon
app->config(
	hypnotoad => {
		listen => [ 'http://*:' . ( $ENV{PORT} || 80 ) ],
		workers => 1,
	},
);

# To serve static files
push @{app->static->paths}, app->home->rel_dir('assets/control-server');

# Helper - redis
app->helper(redis => sub {
	if (!defined $ENV{REDISCLOUD_URL}) {
		warn 'REDISCLOUD_URL is not defined; Please run: $ heroku addons:add rediscloud';
		return undef;
	}
	return Redis->new(server => $ENV{REDISCLOUD_URL});
});
app->helper(push_queue_to_redis => sub {
	my ($s, $type, $content) = @_;
	if (defined $s->redis()) {
		$s->redis()->rpush('queues', Mojo::JSON::encode_json({
			id => time(),
			created_at => time(),
			type => $type,
			content => Mojo::JSON::encode_json($content),
		}));
	} else {
		foreach my $id (keys %deviceClients) {
			$deviceClients{$id}->{tx}->send(Mojo::JSON::encode_json($content));
		}
	}
});

# Helper - Log
app->helper(write_device_log => sub {
	my ($s, $device_name, $message) = @_;

	# Output to log
	$s->app->log->debug("Device log - ${message}");

	# Send to admin clients
	foreach my $id (keys %adminClients) {
		$adminClients{$id}->send(Mojo::JSON::encode_json({
			cmd => 'log',
			log_from => $device_name,
			log_text => $message,
		}));
	}
});

# WebSocket endpoint for push notification to signage device
websocket '/notif' => sub {
	my $s = shift;

	# Set timeout sec
	$s->inactivity_timeout(600);

	# Insert connection into clients hash
	my $client_id = sprintf("%s", $s->tx);
	my $device_name = $client_id;
	if ($device_name =~ /HASH\((.+)\)/) {
		$device_name = $1;
	}
	$deviceClients{$client_id} = {
		name => $device_name,
		tx => $s->tx,
		connected_at => time(),
		config => undef,
	};

	# Set event handlers

	$s->on(json => sub { # Incomming message
		my ($tx, $hash) = @_;
		if (defined $hash->{cmd}) {

			if ($hash->{cmd} eq 'post-log') { # Posting of log
				$s->write_device_log($client_id, $hash->{log_text});

			} elsif ($hash->{cmd} eq 'get-latest-repo-rev') { # Getting of latest revision of repository
				$s->app->log->debug("Received cmd - " . $hash->{cmd});
				$tx->send({ json => {
					cmd => $hash->{cmd},
					repo_rev => $repo_revs{master} || undef, # for old version
					repo_revs => \%repo_revs, # for compatibility with old version
				}});

			} else {
				$s->app->log->warn("Received unknown command - " . $hash->{cmd});

			}
		}
	});

	$s->on(finish => sub { # Closed
		my ($s, $code, $reason) = @_;

		delete $deviceClients{$client_id};

		$s->write_device_log($client_id, "Device diconnected - Code = " . $code);
	});

	$s->write_device_log($client_id, "Device connected");

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

	# Save revision
	if (!defined $payload->{ref} || $payload->{ref} !~ /^refs\/heads\/(.+)/) {
		$s->render(text => 'Invalid target refs', status => 400);
		return;
	}
	my $branch = $1;
	my $rev = $payload->{after};
	$repo_revs{$branch} = $rev;

	# Insert a notification-task to queue
	$s->push_queue_to_redis('notify-to-clients', {
		cmd => 'repository-updated',
		branch => $branch,
	});

	$s->render(text => 'OK:' . $branch);
};

# Administrator console
any '/admin' => sub {
	my $s = shift;

	if (!defined $ENV{VM_SIGNAGE_AUTH_USERNAME} || !defined $ENV{VM_SIGNAGE_AUTH_PASSWORD}) {
		my $msg = <<EOF;
For using administrator area,
You must defined VM_SIGNAGE_AUTH_USERNAME and VM_SIGNAGE_AUTH_PASSWORD on Environment variables.
EOF
		$s->render(text => $msg, status => 400);
		return;
	}

	# Require basic authentication
	$s->res->headers->www_authenticate('Basic');

	# Check for user name and password
	my $basic_str = $ENV{VM_SIGNAGE_AUTH_USERNAME} . ':' . $ENV{VM_SIGNAGE_AUTH_PASSWORD};
	if ($s->req->url->to_abs->userinfo ne $basic_str) {
			my $msg = <<EOF;
Please authentication
EOF
			$s->render(text => $msg, status => 401);
			return;
	}

	# Generate key for websocket authentication
	my $ws_key = Mojo::Util::sha1_sum(time() . '-' . int(rand(9999999)));
	$adminWsKeys{$ws_key} = time();
	$s->stash(ws_key => $ws_key);

	# Output
	$s->render(template => 'admin');
};

# WebSocket endpoint for administrator console
websocket '/admin/ws/:wsKey' => sub {
	my $s = shift;

	my $ws_key = $s->param('wsKey');
	if (!defined $ws_key || !defined $adminWsKeys{$ws_key}) {
		$s->app->log->warn('Admin websocket connection was blocked: ' . $ws_key);
		$s->tx->finish();
		return;
	}

	# Set timeout sec
	$s->inactivity_timeout(600);

	# Insert connection into clients hash
	my $client_id = sprintf("%s", $s->tx);
	$adminClients{$client_id} = $s->tx;

	# Set event handlers

	$s->on(json => sub { # Incomming message
		my ($tx, $hash) = @_;
		if ($hash->{cmd} eq 'restart') {
			# Insert a notification-task to queue
			$s->push_queue_to_redis('notify-to-clients', {
				cmd => 'restart',
			});
		}
	});

	$s->on(finish => sub { # Closed
		my ($s, $code, $reason) = @_;
		delete $adminClients{$client_id};
		delete $adminWsKeys{$ws_key};
	});

	return;
};

# ----

# Loop for ping and queue checking
my $id = Mojo::IOLoop->recurring(5 => sub {
	# Make the signage device list
	my @devices = ();
	foreach my $id (keys %deviceClients) {
		my %device = %{$deviceClients{$id}};
		push(@devices, \%device);
	}

	# Ping to signage devices
	foreach my $id (keys %deviceClients) {
		eval {
			$deviceClients{$id}->{tx}->send(Mojo::JSON::encode_json({
				cmd => 'device-ping',
				created_at => time(),
			}));
		};
	}

	# Ping to admin console
	foreach my $id (keys %adminClients) {
		# Send to admin console
		eval {
			$adminClients{$id}->send(Mojo::JSON::encode_json({
				cmd => 'device-list',
				devices => \@devices
			}));
		};
	}

	# Queue checking
	my $redis = undef;
	if (!defined app->redis()) {
		return;
	}

	my $len = $redis->llen('queues');
	if ($len <= 0) {
		return;
	}
	for (my $i = 0; $i < $len; $i++) {
		my $task = Mojo::JSON::decode_json($redis->lindex('queues', $i));
	}
});

# Start the server
app->start;

__DATA__

@@ admin.html.ep
<!DOCTYPE html>
<html>
	<head>
		<title>vm-signage</title>
		%= javascript '/mojo/jquery/jquery.js'
		<script>
			var WS_KEY = '<%= stash 'ws_key' %>';
		</script>
		%= javascript '/js/admin.js'
	</head>
	<body>
		<h1>vm-signage</h1>

		<h2>Connected devices</h2>
		<ul id="deviceList"></ul>

		<h2>Commands</h2>
		<button id="btnRestart" href="javascript:void(0);">Restart devices</button>

		<h2>Log</h2>
		<ul id="logger"></ul>

	</body>
</html>
