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

			var $name = $('<p/>');
			if (d.config != null && d.git_branch_name != null) {
				$name.text(d.name + ' (' + d.git_branch_name + ')');
			} else {
				$name.text(d.name);
			}
			$li.append($name);

			var $info = $('<span/>');
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
