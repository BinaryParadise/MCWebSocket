function DBManager(url, onmessage) {
	title = "iOS数据库查询";
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
			client.send(JSON.stringify({type:0}));
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
	
	window.wsmgr = this;
	this.open();	
	setInterval("window.wsmgr.open()",5000);
};

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
	
	window.wsmgr = this;
	this.open();	
	setInterval("window.wsmgr.open()",5000);
};