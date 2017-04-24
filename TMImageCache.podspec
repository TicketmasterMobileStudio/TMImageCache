Pod::Spec.new do |s|
  s.name             = 'TMImageCache'
  s.version          = '0.1.1'
  s.summary          = 'Fast, efficient image caching'

  s.description      = <<-DESC
Fast, efficient image caching
                       DESC

  s.homepage         = 'https://github.com/TicketmasterMobileStudio/TMImageCache'
  #s.license          = {  }
  s.author           = { 'Chris Stroud' => 'chris.stroud@ticketmaster.com' }
  s.source           = { :git => 'https://github.com/TicketmasterMobileStudio/TMImageCache.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'TMImageCache/Classes/**/*'
  s.frameworks = 'UIKit'
  s.dependency 'CryptoSwift', '~> 0.6'
end
