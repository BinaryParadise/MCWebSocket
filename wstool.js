var title = "WebSocket客户端示例";

function sendMessage() {
	if (client != undefined) {
		var msg = $("#sql").val();
		localStorage.setItem("sql", msg);
		client.send(msg);
		console.info((/function\s*(\w*)/i.exec(arguments.callee.toString())[1]) + ": length=" + msg.length);
	} else {
		console.error("WebSocket未初始化");
	}
}

function LogManager(url, onmessage, binary) {
	title = "WebSocket在线测试";
	var log = this;
	this.url = url;
	this.onmessage = onmessage;
	var client;
	this.open = function () {
		if (client != undefined && client.readyState == 1) {
			return;
		}
		log.onmessage({ level: -1, msg: "开始连接到 " + log.url + " ..." });
		if (WebSocket != undefined) {
			client = new WebSocket(this.url);
		} else {
			client = new window.MozWebSocket(this.url);
		}
		if (binary) {
			client.binaryType = "arraybuffer";
		}
		this.client = client;

		client.onopen = function () {
            this.send(str2ab("abcdefghijkmlnopqrstuvwxyz"))
			log.onmessage({ level: 0, msg: client.url + " 连接成功..." });
		};

		client.onerror = function (event) {
			console.error(event);
			log.onmessage({ level: -1, msg: event.msg });
		};

		client.onclose = function (event) {
			console.log(event);
			log.onmessage({ level: -1, msg: "连接已关闭" });
		};

		client.onmessage = function (event) {
			log.onmessage({
				level: typeof event.data == "string" ? 1 : 2, msg: event.data
			})
		};
	};

	window.logmgr = this;
	this.open();
	setInterval("window.logmgr.open()", 5000);
}

// 字符串转为ArrayBuffer对象，参数为字符串
const str2ab = function (str) {
	var buf = new ArrayBuffer(str.length * 2); // 每个字符占用2个字节
	var bufView = new Uint8Array(buf);
	for (var i = 0, strLen = str.length; i < strLen; i++) {
		bufView[i] = str.charCodeAt(i);
	}
	return bufView;
}
