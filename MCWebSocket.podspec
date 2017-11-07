Pod::Spec.new do |s|

	s.name         = "MCWebSocket"
	s.version      = "1.1.0"
	s.summary      = "MCWebSocket is a objective-c implementation of the WebSocket protocol."
	s.description  = 'websocket protocol rfc4655(https://tools.ietf.org/html/rfc6455).
	实现了websocket协议，顺便学习下，一点点写吧，还有很多没有完成的地方，主要英语太差了很多资料都看不懂'
	
	s.homepage     = "https://github.com/mylcode/MCWebSocket"
	s.license      = { :type => 'MIT', :file => 'LICENSE'}
	s.author             = { "mylcode" => "rmacbookpro@163.com" }
	
	s.ios.deployment_target = "8.0"
	s.osx.deployment_target = "10.9"
	
	s.source       = { :git => "https://github.com/mylcode/MCWebSocket.git", :tag => s.version.to_s }
	
	s.default_subspec = 'standard'
	s.requires_arc = true

	s.subspec 'standard' do |ss|
    	ss.source_files = 'MCWebSocket/Classes/*'
    	ss.exclude_files    = 'MCWebSocket/Classes/DB/*'
    	ss.dependency   'CocoaAsyncSocket', '~> 7.6.0'
        ss.dependency   'MCLogger'
  	end

	s.subspec 'DB' do |ss|
		ss.source_files = 'MCWebSocket/Classes/DB/*'
		ss.dependency   'MCWebSocket/standard'
        ss.dependency   'FMDB'
        ss.dependency   'MCJSONKit'
	end

	s.subspec 'NSLog' do |ss|
		ss.source_files = 'MCWebSocket/Classes/NSLog/*'
		ss.dependency   'MCWebSocket/standard'
        ss.dependency   'MCJSONKit'
	end

end
