$(function () {

	// Write of log
	var writeLog = function(msg, sender) {
		var $li = $('<li/>');
		var now = new Date();
		if (sender == undefined) {
			sender = "System";
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
			$li.text(d.id);
			$device_list.append($li);
		}
	};

	/* ---- */

	// Connect to server
	var ws = new WebSocket('ws://' + window.location.host + '/admin/ws/' + WS_KEY);

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
			updateDeviceList(data.devices);
		}
	};
});
