Pod::Spec.new do |s|
  s.name = 'CorePromise'

  s.version = '1.0.3'
  
  s.homepage = "https://github.com/naftaly/CorePromise"
  s.source = { :git => "https://github.com/naftaly/CorePromise.git", :tag => s.version }
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'CorePromise is a Promise framework.'

  s.social_media_url = 'https://twitter.com/naftaly'
  s.authors  = { 'Alexander Cohen' => 'naftaly@me.com' }

  s.requires_arc = true

  s.ios.deployment_target = '9.0'
	
  s.ios.source_files = [ 'CorePromise/CorePromise.h', 
    'CorePromise/CPPromise.h', 
    'CorePromise/CPPromise.m', 
    'CorePromise/CPPromise+Foundation.h', 
    'CorePromise/CPPromise+Foundation.m', 
    'CorePromise/CPPromise+UIKit.h', 
    'CorePromise/CPPromise+UIKit.m' ]
  s.ios.public_header_files = [ 'CorePromise/CorePromise.h', 
    'CorePromise/CPPromise.h', 
    'CorePromise/CPPromise+Foundation.h', 
    'CorePromise/CPPromise+UIKit.h' ]
    
    s.osx.source_files = [ 'CorePromise/CorePromise.h', 
      'CorePromise/CPPromise.h', 
      'CorePromise/CPPromise.m', 
      'CorePromise/CPPromise+Foundation.h', 
      'CorePromise/CPPromise+Foundation.m' ]
    s.osx.public_header_files = [ 'CorePromise/CorePromise.h', 
      'CorePromise/CPPromise.h', 
      'CorePromise/CPPromise+Foundation.h' ]
end
