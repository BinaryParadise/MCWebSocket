
function startWS(url) {
	var client;
	if (WebSocket != undefined) {
		client = new WebSocket(url);
	}else {
		client = new window.MozWebSocket(url);
	}
	client.binaryType = "arraybuffer";
	client.onopen = function() {
		console.log(client.url + " 连接成功...");
	};

	client.onerror = function(event) {
		console.error(event);
	};

	client.onclose = function(event) {
		console.log(event);
	};

	client.onmessage = function(event) {
		var obj = eval('('+event.data+')');
		if (obj.code == 0) {
			var data = obj.data;
			var result = "<tr>";
			for (var i = 0; i < data[0].length; i++) {
				result += "<th scope='col'>" +data[0][i]+ "</th>";
			}
			result += "</tr>";
			for (var i = 1; i < data.length; i++) {
				result += "<tr>";
				for(var item in data[i]) {
					result += "<td>"+data[i][item]+"</td>";
				}
				result += "</tr>";
			}

			$("#rstable").html(result);
		}else {
			$("#rstable").text(obj.msg);
		}

	};
}

function sendMessage() {
	if (client != undefined) {
		var msg = $("#sql").val();
		localStorage.setItem("sql",msg);
		client.send(msg);
		console.info((/function\s*(\w*)/i.exec(arguments.callee.toString())[1])+": length="+msg.length);
	}else {
		console.error("WebSocket未初始化");
	}
}

function LogManager(url, onmessage) {
	title = "iOS日志查看器";
	var log = this;
	this.url = url;
	this.onmessage = onmessage;
	var client;
	this.open = function() {		
		if (client != undefined && client.readyState == 1) {
			return;
		}
		log.onmessage({level:-1,msg:"开始连接到 "+log.url+" ..."});
		if (WebSocket != undefined) {
			client = new WebSocket(this.url);
		}else {
			client = new window.MozWebSocket(this.url);
		}
		client.binaryType = "arraybuffer";
		this.client = client;

		client.onopen = function() {
			console.log(client.url + " 连接成功...");
			log.onmessage({level:0, msg:client.url + " 连接成功..."});
		};

		client.onerror = function(event) {
			console.error(event);
			log.onmessage({level:-1,msg:event.msg});		
		};

		client.onclose = function(event) {
			console.log(event);
			log.onmessage({level:-1,msg:"连接已关闭"});			
		};

		client.onmessage = function(event) {
			var obj = eval('('+event.data+')');
			log.onmessage(obj);
		};
	};
	
	window.logmgr = this;
	this.open();	
	setInterval("window.logmgr.open()",5000);
}