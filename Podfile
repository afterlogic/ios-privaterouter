# Uncomment the next line to define a global platform for your project
platform :ios, '8.0'

target 'PrivateMail' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  inhibit_all_warnings!
  
  # Pods for PrivateMail

  pod 'ObjectivePGP', '~> 0.15.0'
  pod 'SideMenu', '~> 5.0.1'
  pod 'SVProgressHUD', '~> 2.2.5'
  pod 'SDWebImage', '~> 5.3.1'
  pod 'KeychainAccess', '~> 4.1.0'
  pod 'RealmSwift', '~> 4.1.1'
  pod 'SwiftTheme', '~> 0.4.7'
  pod 'DropDown', '2.3.12'

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

    }

    installer.pods_project.targets.each do |target|

      swift_version = POD_SWIFT_VERSION_MAP[target.name] || DEFAULT_SWIFT_VERSION

      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = swift_version
      end

    end

    #endregion

    #region: MARK: - Bitcode
    # ObjectivePGP doesn't contain bitcode, so disable for all.

    installer.pods_project.targets.each do |target|

      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end

    end

    #endregion

  end

end
