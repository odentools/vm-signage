# vm-signage
A simple digital signage kit for Raspberry Pi 1 or 2 (with Raspbian).

[![Build Status](https://secure.travis-ci.org/mugifly/vm-signage.png?branch=master)](http://travis-ci.org/mugifly/vm-signage)

## Components

This kit is composed with 2 components.

### Signage-device script

The signage-device script will be used by deployed on your Raspberry Pi.
It makes the Raspberry Pi metamorphoses into an digital-signage device.

In the case of normally, the Raspberry Pi should be connecting with any HDMI display or VGA display.

### Control-server script

The control-server script will be used by deployed on [Heroku](https://www.heroku.com/) or your any server.

The control-server allows auto updating of signage when your any repository has pushed.
However, whether to use of this function is optional;
If you won't use it, you don't need to use the control-server.

## Files
* Procfile - File for control-server (for deploying to Heroku)
* control-server.pl - Control-server script
* cpanfile - Definition of dependent modules
* signage-device.pl - Signage-device script (for Raspberry Pi)

## Quick Installation

If you want to make a digital-signage quickly, that's enough only to run the step 3 of Installation steps on your Raspberry Pi.
In addition, In the configuration file, please set a blank into the *control_server_ws_url* parameter.

Let turn on your Rasppberry Pi!

## Installation

### 1. Forking of Repository

If you will customize this kit, You should fork the repository from https://github.com/mugifly/vm-signage.
Then please make a customizing into your forked repository.

### 2. Deployment of Control-server on Heroku

Firstly, signup on the [Heroku](https://www.heroku.com/). And install the [Heroku Toolbelt](https://toolbelt.heroku.com/) on your computer.

Then, please run the following commands on your computer:

    $ git clone https://github.com/YOURNAME/vm-signage.git
    $ cd vm-signage/
    $ heroku create --buildpack https://github.com/kazeburo/heroku-buildpack-perl-procfile.git
    $ git push heroku master
    $ heroku open

### 3. Installation of Signage-device on Raspberry Pi

Firstly, run the following commands on your Raspberry Pi:

    $ sudo apt-get install perl git chromium x11-xserver-utils
    $ sudo cpan install Carton
    $ cd ~
    $ git clone https://github.com/YOURNAME/vm-signage.git
    $ cd vm-signage/
    $ carton install

(NOTE: If connected network needed a proxy to access WAN, you should run the command  that like follows before above commands: $ export http_proxy="http://proxy.example.com:8080". Then when the run the sudo command, you might want to add -E option.)

Then, make a script file as follows: *start.sh*

````bash
#!/bin/bash
cd ~/vm-signage
carton exec -- perl signage-device.pl
````

Then, make a configuration file as follows: *config/signage-device.conf*

````perl
{
	# Startup (Optional)
	startup_wait_sec => 5, # Or undef

	# Signage browser
	chromium_bin_path => 'chromium',
	signage_page_url => 'http://example.com/',

	# Proxy (Optional)
	http_proxy => 'http://proxy.example.com:8080', # Or undef

	# Control server (Optional; Websocket URL of deployed server)
	control_server_ws_url => 'wss://example.herokuapp.com/', # Or undef

	# Auto updating with using Git (Optional)
	git_cloned_dir_path => '/home/pi/vm-signage/', # Or undef
	git_repo_name => 'origin',
	git_branch_name => 'master',
	git_bin_path => '/usr/bin/git',

	# Sleep of display (Optional)
	sleep_begin_time => '21:59', # Or undef
	sleep_end_time => '07:00', # Or undef
}
````

(NOTE: If you won't use control-server, these parameters should be set the undef: "control_server_ws_url", "git_cloned_dir_path".)

After that, add the following line into the LXDE autostart file: *~/.config/lxsession/LXDE-pi/autostart*

````text
@/bin/bash ~/vm-signage/start.sh
````

Finally, please reboot the Raspberry Pi. Let's enjoy :)

    $ sudo shutdown -r now

### 4. Add Webhook on GitHub

To auto updating signage when any your any repository was pushed,
please register the following settings on the "Webhook" section of
"Settings - Webhooks & Services" page of the forked repository on GitHub.

* Payload URL: https://example.heroku.com/github-webhook-receiver
* Content type: application/json
* Secret: (empty)
* Which events would you like to trigger this webhook?: Just the push event
* Active: (true)

## Hints

### How to disable sleeping of the HDMI display

Please edit following files.

In the line that begin from @xscreensaver should be commented out.
And add some @xset line.

*/etc/xdg/lxsession/LXDE/autostart*

    #@xscreensaver -no-splash

*/etc/xdg/lxsession/LXDE-pi/autostart*

    #@xscreensaver -no-splash
    @xset s off
    @xset -dpms
    @xset s noblank

## License

Copyright (C) 2015 Masanori Ohgita (http://ohgita.info/).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 (GPL v3).
