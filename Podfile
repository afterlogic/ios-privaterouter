# Uncomment the next line to define a global platform for your project
platform :ios, '8.0'

target 'PrivateMail' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  inhibit_all_warnings!
  
  # Pods for PrivateMail

  pod 'ObjectivePGP', '~> 0.13.0'
  pod 'SideMenu', '~> 4.0.0'
  pod 'SVProgressHUD', '~> 2.2.5'
  pod 'SDWebImage', '~> 4.4.5'
  pod 'KeychainAccess', '~> 3.1.2'
  pod 'RealmSwift', '~> 3.16.2'
  pod 'SwiftTheme', '~> 0.4.7'
  
  target 'PrivateMailTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'PrivateMailUITests' do
    inherit! :search_paths
    # Pods for testing
  end

  post_install do |installer|

    #region: MARK: - Pods swift version
    
    DEFAULT_SWIFT_VERSION = '5.1'
    POD_SWIFT_VERSION_MAP = {
        'SideMenu' => '4.0'
    }

    installer.pods_project.targets.each do |target|

      swift_version = POD_SWIFT_VERSION_MAP[target.name] || DEFAULT_SWIFT_VERSION

      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = swift_version
      end

    end

    #endregion

  end

end
