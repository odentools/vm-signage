# vm-signage
A simple digital signage kit for Raspberry Pi (Wheezy).

## Components

This kit is composed with 2 components.

### Signage-device script

The signage-device script will be used by deployed on your Raspberry Pi.
It makes the Raspberry Pi metamorphoses into an digital-signage device.

In the case of normally, the Raspberry Pi should be connecting with any HDMI display or VGA display.

### Control-server script

The control-server script will be used by deployed on [Heroku](https://www.heroku.com/) or your any server.

You can also use the signage-device as standalone; Actually, using of the control-server is optional, but it allows auto updating of your signage.

## Files
* Procfile - File for control-server (for deploying to Heroku)
* control-server.pl - Control-server script
* cpanfile - Definition of dependent modules
* signage-device.pl - Signage-device script (for Raspberry Pi)

## Installation

### Control-server on Heroku

Firstly, signup on the [Heroku](https://www.heroku.com/). And install the [Heroku Toolbelt](https://toolbelt.heroku.com/) on your computer.

Then, please run the following commands on your computer:

    $ git clone https://github.com/odentools/vm-signage.git
    $ cd vm-signage/
    $ heroku create --buildpack https://github.com/kazeburo/heroku-buildpack-perl-procfile.git
    $ git push heroku master
    $ heroku open

### Signage-device on Raspberry Pi

Please run the following commands on your Raspberry Pi:

    $ sudo apt-get install chromium
    $ sudo cpan install Carton
    $ git clone https://github.com/odentools/vm-signage.git

Then, write a configuration file: 
config/signage-device.conf

	{
		# Control server (URL of deployed server on Heroku)
		control_server_ws_url => 'ws://FOO.heroku.com/',

		# Signage browser
		chromium_bin_path => 'chromium',
		signage_page_url => 'http://example.com/',
		
		# Proxy
		http_proxy => 'http://proxy.example.net:8080', # Or undef
		
		# Auto updating with using Git
		git_cloned_dir_path => '/home/pi/vm-signage/',
		git_repo_name => 'origin',
		git_branch_name => 'master',
		git_bin_path => '/usr/bin/git',
		
		# Sleep
		sleep_begin_time => '21:59',
		sleep_end_time => '07:00',
	}

## License

Copyright (C) 2015 OdenTools Project (https://sites.google.com/site/odentools/), Masanori Ohgita (http://ohgita.info/).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 (GPL v3).

