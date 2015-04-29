# vm-signage
A simple digital signage kit for Raspberry Pi (Wheezy).

## Components

### control-server

### signage-device

## Files
* Procfile - File for control-server (Use for working on Heroku)
* app.psgi - File for control-server (Use for working on Heroku)
* control-server.pl - Control-server
* cpanfile - Definition of dependent modules
* signage-device.pl - Signage script for Raspberry Pi

## Installation

### control-server on Heroku

Firstly, signup on the [Heroku](https://www.heroku.com/). And install the [Heroku Toolbelt](https://toolbelt.heroku.com/) on your computer.

Then, please run the following commands on your computer:

    $ git clone https://github.com/odentools/vm-signage.git
    $ cd vm-signage/
    $ heroku create --buildpack https://github.com/kazeburo/heroku-buildpack-perl-procfile.git
    $ git push heroku master
    $ heroku open

### signage-device on Raspberry Pi

Please run the following commands on your Raspberry Pi:

    $ sudo apt-get install chromium
    $ sudo cpan install Carton
    $ git clone https://github.com/odentools/vm-signage.git

Then, write a configuration file: 
config/signage-device.conf

	{
		# Control server
		control_server_ws_url => 'ws://FOO.heroku.com/',

		# Signage browser
		chromium_bin_path => 'chromium',
		signage_page_url => 'http://example.com/',
		
		# Proxy
		http_proxy => 'http://proxy.example.net:8080', # Or undef
		
		# Auto updating with using Git
		git_cloned_dir_path => '/path/to/signage/',
		git_repo_name => 'origin',
		git_branch_name => 'master',
		git_bin_path => '/usr/bin/git',
		
		# Sleep
		sleep_begin_time => '21:59',
		sleep_end_time => '07:00',
	}

## License

Copyright (C) 2013 OdenTools Project (https://sites.google.com/site/odentools/), Masanori Ohgita (http://ohgita.info/).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 (GPL v3).

