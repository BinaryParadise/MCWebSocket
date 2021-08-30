Pod::Spec.new do |s|

	s.name         = "MCWebSocket"
	s.version      = "1.2.0"
	s.summary      = "MCWebSocket is a objective-c implementation of the WebSocket protocol."
	s.description  = 'websocket protocol rfc4655(https://tools.ietf.org/html/rfc6455).
	实现了websocket协议，顺便学习下，一点点写吧，还有很多没有完成的地方，主要英语太差了很多资料都看不懂
	2021年08月30日改为swift实现
	'
	
	s.homepage     = "https://github.com/mylcode/MCWebSocket"
	s.license      = { :type => 'MIT', :file => 'LICENSE'}
	s.author             = { "mylcode" => "rmacbookpro@163.com" }
	
	s.ios.deployment_target = "8.0"
	s.osx.deployment_target = "10.9"
	
	s.source       = { :git => "https://github.com/mylcode/MCWebSocket.git", :tag => s.version.to_s }
	
	s.default_subspec = 'standard'
	s.requires_arc = true

    s.source_files = 'Sources/**/*'
    #TODO: PracticeTLS pod

end
