$(function () {

	// Write of log
	var writeLog = function(msg, sender) {
		var $li = $('<li/>');
		var now = new Date();
		if (sender == undefined) {
			sender = "Me";
		}
		$li.text("[" + sender + "] " + now + " - " + msg);
		$('#logger').prepend($li);
	};

	// Update of device list
	var updateDeviceList = function(devices) {
		var $device_list = $('#deviceList');
		$device_list.empty();

		for (var i = 0, l = devices.length; i < l; i++) {
			var d = devices[i];
			var $li = $('<li/>');

			var $caption = $('<p/>');
			$caption.addClass('device-caption');
			var $name = $('<span/>');
			if (d.config != null && d.config.git_branch_name != null) {
				$name.text(d.name + ' (' + d.config.git_branch_name + ')');
			} else {
				$name.text(d.name);
			}
			$caption.append($name);
			if (d.config != null && d.config.signage_page_url != null) {
				var $page_link = $('<a/>');
				var url = d.config.signage_page_url;
				url = url.replace(/\\\#/g, '#');
				$page_link.attr('href', url);
				$page_link.attr('target', '_blank');
				$page_link.text('ページ');
				$caption.append($page_link);
			}
			$li.append($caption);

			var $info = $('<span class="device-info"/>');
			$info.text(JSON.stringify(d));
			$li.append($info);

			$device_list.append($li);
		}
	};

	/* ---- */

	// Connect to server
	var ws_scheme = 'ws://';
	if (window.location.protocol == 'https:') {
		ws_scheme = 'wss://';
	}
	var ws = new WebSocket(ws_scheme + window.location.host + '/admin/ws/' + WS_KEY);

	ws.onopen = function() {
		writeLog("Connected to server");

		// Set event handler
		$('#btnRestart').click(function(){
			ws.send(JSON.stringify({
				'cmd': 'restart',
			}));
			writeLog("Sent command: restart");
		});
	};

	ws.onmessage = function(msg) {
		// JSON parse
		var data = null;
		try {
			data = $.parseJSON(msg.data);
		} catch (e) {
			writeLog("System", "Received a message; However it could not parse as JSON.");
			return;
		}

		// Check command type
		if (data.cmd == undefined) {
			return;
		}

		if (data.cmd == "log") {
			writeLog(data.log_text, data.log_from);
		} else if (data.cmd == "device-list") {
			console.log(data.devices); // TODO
			updateDeviceList(data.devices);
		}
	};
});
