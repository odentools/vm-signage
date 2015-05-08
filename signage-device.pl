#!/usr/bin/env perl
# VM Signare - Signature device
use strict;
use warnings;
use FindBin;
use Mojo::UserAgent;
use Time::Piece;

# Disable buffering
$| = 1;

# Read configurations
our %config = read_configs();
check_configs();

# Read parameters
check_params();

# Start browser for signage
if (defined $config{startup_wait_sec}) {
	wait_sec($config{startup_wait_sec});
}
exec_signage();

# Connect to control server with using WebSocket
my $ua;
my $ws_url = $config{control_server_ws_url} || undef;
if (defined $ws_url) {
	$ua = Mojo::UserAgent->new();
	if (defined $config{http_proxy}) {
		$ua->proxy->http($config{http_proxy})->https($config{http_proxy});
	}
	$ua->inactivity_timeout(3600); # 60min
	$ua->websocket($ws_url.'notif' => sub {
		my ($ua, $tx) = @_;
		if (!$tx->is_websocket) {
			log_e("WebSocket handshake failed: ${ws_url}notif");
			# Restart myself
			wait_sec(5);
			restart_myself();
			exit;
		}
		log_i("WebSocket connected");

		# Check latest revision of repository
		$tx->send({ json => {
				cmd => 'get-latest-repo-rev',
		}});

		# Set event handler
		$tx->on(json => sub { # Incomming message
			my ($tx, $hash) = @_;
			if ($hash->{cmd} eq 'repository-updated') { # On repository updated
				log_i("Repository updated");
				# Update repository
				update_repo();
				# Restart myself
				$tx->finish;
				wait_sec(5);
				restart_myself();
				exit;
			} elsif ($hash->{cmd} eq 'get-latest-repo-rev' && exists $hash->{repo_rev}) { # On revision received
				my $local_rev = get_repo_rev();
				log_i("local = $local_rev, remote = $hash->{repo_rev}");
				if (defined $hash->{repo_rev} && $hash->{repo_rev} ne $local_rev) {
					log_i("Repository was old: $local_rev");
					# Update repository
					update_repo();
					$local_rev = get_repo_rev();
					if ($hash->{repo_rev} ne $local_rev) {
						log_i("Git working directory has updated; But both were different: $local_rev <> $hash->{repo_rev}");
						return;
					}
					# Restart myself
					$tx->finish;
					wait_sec(5);
					restart_myself();
				}
			} else {
				warn '[WARN] Received unknown command ... ' . Mojo::JSON::encode_json($hash);
			}
		});
		$tx->on(finish => sub { # Closed
			my ($s, $code, $reason) = @_;
			log_i("WebSocket connection closed ... Code=$code");
			# Restart myself
			wait_sec(10);
			restart_myself();
			exit;
		});
	});
}

# Prepare for display sleeping
my ($sleep_begin_time, $sleep_end_time) = (0, 0);
if (defined $config{sleep_begin_time} && defined $config{sleep_end_time}) {
	$sleep_begin_time =  time_str_to_num($config{sleep_begin_time});
	$sleep_end_time = time_str_to_num($config{sleep_end_time});
}
log_i("Initialize completed");

# Define main loop
my $is_sleeping = -1; # This flag may be reset by restarting of script
my $id = Mojo::IOLoop->recurring(2 => sub {
	my $now_s = int(Time::Piece::localtime->strftime('%H%M'));
	if ($sleep_begin_time != 0 && ($sleep_begin_time <= $now_s || $now_s < $sleep_end_time)) {
		# Start display sleeping
		if ($is_sleeping != 1) {
			$is_sleeping = 1;
			set_display_power(0);
		}
	} elsif ($sleep_end_time != 0 && $sleep_end_time <= $now_s) {
		# Reboot for to end display sleeping
		if ($is_sleeping != 0) {
			$is_sleeping = 0;
			set_display_power(1);
		}
	}
});

# Start loops
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

exit;

# ----

# Read an configuration
sub read_configs {
	my $conf_path = "${FindBin::Bin}/config/signage-device.conf";
	if (!-f $conf_path) {
		log_e("Config file is not found: $conf_path", 1);
	}
	my %conf = %{eval slurp("${FindBin::Bin}/config/signage-device.conf")};
	if ($@) {
		log_e("Config file could not read: $conf_path", 1);
	}
	return %conf;
}

# Check an configuration
sub check_configs {
	if (defined $config{control_server_ws_url} || defined $config{git_cloned_dir_path}) {
		my @param_names = qw/ control_server_ws_url git_cloned_dir_path git_repo_name git_branch_name git_bin_path /;
		foreach (@param_names) {
			if (!defined $config{$_}) {
				log_e("Config - $_ undefined", 1);
			}
		}
	}
}

# Check a parameter
sub check_params {
	my $is_no_update = 0;
	foreach (@ARGV) {
		if ($_ eq '--no-update') {
			$is_no_update = 1;
		} elsif ($_ eq '--help' || $_ eq '-h') {
			print_help();
			exit;
		} elsif ($_ eq '--debug') {
			$config{is_debug} = 1;
		}
	}
	if (!$is_no_update) {
		# Update and restart
		update_repo();
		push(@ARGV, '--no-update');
		restart_myself();
	}
}

# Print help
sub print_help {
	print "$0 [--help|-h] [--no-update]\n";
}

# Execute signage
sub exec_signage {
	return if (defined $config{is_debug});

	log_i("Signage browser starting...");
	my $prefix = '';
	if (defined $config{http_proxy} && $config{http_proxy} ne '') {
		$prefix = 'http_proxy="' . $config{http_proxy} . '" ';
	}
	print `$prefix$config{chromium_bin_path} --kiosk "$config{signage_page_url}" &` . "\n";
	log_i("Signage browser started");
}

# Get revision of Git repository
sub get_repo_rev {
	chdir($config{git_cloned_dir_path});
	my $rev = `$config{git_bin_path} show -s --format=%H`;
	chomp($rev);
	return $rev;
}

# Update Git repository
sub update_repo {
	return if (defined $config{is_debug});

	log_i("Updating repository...", 1);
	chdir($config{git_cloned_dir_path});
	`$config{git_bin_path} fetch $config{git_repo_name} $config{git_branch_name}`;
	`$config{git_bin_path} reset --hard FETCH_HEAD`;
	chdir($FindBin::Bin);
	my $path_bin_carton = `which carton`;
	chomp($path_bin_carton);
	#`$path_bin_carton install`; # TODO
	print "Done\n";
}

# Set sleeping state of display
sub set_display_power {
	return if (defined $config{is_debug});

	my $is_power = shift;
	if (!$is_power) {
		log_i("Display sleeping start");
		print `vcgencmd display_power 0`;
	} else {
		log_i("Display sleeping end");
		print `vcgencmd display_power 1`;
	}
}

# Convert time string (12:00) to number (1200)
sub time_str_to_num {
	my $time_str = shift;
	my @parts = split(/:/, $time_str);
	if (!@parts || @parts != 2) {
		return undef;
	}
	return int(sprintf("%02d%02d", $parts[0], $parts[1]));
}

# Wait for specified seconds
sub wait_sec {
	my $sec = shift;
	log_i("Waiting", 1);
	for (my $i = 0; $i < $sec; $i++) {
		print ".";
		sleep(1);
	}
	print "\n";
}

# Restart script
sub restart_myself {
	log_i("Restarting...");
	exec($^X, $0, @ARGV);
}

# Read content from specified file
sub slurp {
	my $path = shift; 
	open my $file, '<', $path;
	my $content = '';
	while ($file->sysread(my $buffer, 131072, 0)) { $content .= $buffer }
	return $content;
}

# Output log as information
sub log_i {
	my ($mes, $opt_no_break_line) = @_;
	my $now = time();
	print "[INFO:$now]  $mes";
	if (!defined $opt_no_break_line || !$opt_no_break_line) {
		print "\n";
	}
}

# Output log as error
sub log_e {
	my ($mes, $opt_is_die) = @_;
	my $now = time();
	if (defined $opt_is_die && $opt_is_die) {
		die "[ERROR:$now]  $mes";
	} else {
		print "[ERROR:$now]  $mes\n";
	}
}
