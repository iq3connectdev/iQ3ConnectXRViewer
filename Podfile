# Uncomment the next line to define a global platform for your project
platform :ios, '17.0'

target 'iQ3ConnectXRViewer' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
    use_frameworks!

  # Pods for ArDemo
  # https://github.com/CåocoaLumberjack/CocoaLumberjack/issues/882
    pod 'CocoaLumberjack'
    pod 'CocoaLumberjack/Swift'
    # Point to fork of https://github.com/Orderella/PopupDialog that allows for wide alerts
    pod 'PopupDialog', :git => 'https://github.com/robomex/PopupDialog.git', :branch => 'wide-alerts'
    pod 'pop'
    pod 'FontAwesomeKit'
end


# Enable DEBUG flag in Swift for SwiftTweaks
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
        end

    end
end
