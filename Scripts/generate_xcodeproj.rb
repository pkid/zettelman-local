require 'fileutils'
require 'xcodeproj'

PROJECT_NAME = 'ZettelmanLocal'.freeze
PROJECT_PATH = File.expand_path('../ZettelmanLocal.xcodeproj', __dir__)
APP_ROOT = 'ZettelmanLocal'.freeze
TEST_ROOT = 'ZettelmanLocalTests'.freeze
BUNDLE_IDENTIFIER = 'com.example.zettelmanlocal'.freeze
IOS_DEPLOYMENT_TARGET = '17.0'.freeze

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastUpgradeCheck'] = '2600'
project.root_object.attributes['LastSwiftUpdateCheck'] = '2600'

app_target = project.new_target(:application, PROJECT_NAME, :ios, IOS_DEPLOYMENT_TARGET)
app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_IDENTIFIER
  config.build_settings['INFOPLIST_FILE'] = "#{APP_ROOT}/Resources/Info.plist"
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = IOS_DEPLOYMENT_TARGET
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
end

test_target = project.new_target(:unit_test_bundle, "#{PROJECT_NAME}Tests", :ios, IOS_DEPLOYMENT_TARGET)
test_target.add_dependency(app_target)
test_target.add_system_framework('XCTest')
test_host_path = '$(BUILT_PRODUCTS_DIR)/ZettelmanLocal.app/ZettelmanLocal'
test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BUNDLE_IDENTIFIER}.tests"
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = IOS_DEPLOYMENT_TARGET
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['TEST_HOST'] = test_host_path
  config.build_settings['BUNDLE_LOADER'] = test_host_path
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
end

main_group = project.main_group
app_group = main_group.new_group(PROJECT_NAME, APP_ROOT)
test_group = main_group.new_group("#{PROJECT_NAME}Tests", TEST_ROOT)
app_subgroups = {
  'App' => app_group.new_group('App', 'App'),
  'Models' => app_group.new_group('Models', 'Models'),
  'Services' => app_group.new_group('Services', 'Services'),
  'Features' => app_group.new_group('Features', 'Features'),
  'Resources' => app_group.new_group('Resources', 'Resources')
}
features_subgroups = {
  'Appointments' => app_subgroups['Features'].new_group('Appointments', 'Appointments'),
  'Scanner' => app_subgroups['Features'].new_group('Scanner', 'Scanner')
}

source_paths = [
  'App/ContentView.swift',
  'App/ZettelmanLocalApp.swift',
  'Models/AppointmentRecord.swift',
  'Models/ExtractedAppointment.swift',
  'Services/AppointmentExtractor.swift',
  'Services/AppointmentPresentation.swift',
  'Services/AppointmentScanner.swift',
  'Services/OCRImagePreprocessor.swift',
  'Services/ScannedImageStore.swift',
  'Services/TextRecognizer.swift',
  'Features/Appointments/AppointmentDetailView.swift',
  'Features/Appointments/AppointmentListView.swift',
  'Features/Scanner/CameraPicker.swift',
  'Features/Scanner/PhotoLibraryPicker.swift',
  'Features/Scanner/ScanConfirmationView.swift'
]

test_source_paths = [
  'AppointmentExtractorFixtureTests.swift',
  'SampleScanIntegrationTests.swift'
]

source_paths.each do |relative_path|
  group = case relative_path
          when /^App\// then app_subgroups['App']
          when /^Models\// then app_subgroups['Models']
          when /^Services\// then app_subgroups['Services']
          when /^Features\/Appointments\// then features_subgroups['Appointments']
          when /^Features\/Scanner\// then features_subgroups['Scanner']
          else
            app_group
          end

  file_ref = group.new_file(File.basename(relative_path))
  app_target.add_file_references([file_ref])
end

test_source_paths.each do |relative_path|
  file_ref = test_group.new_file(relative_path)
  test_target.add_file_references([file_ref])
end

resources = [
  'Resources/Assets.xcassets'
]
resources.each do |relative_path|
  file_ref = app_subgroups['Resources'].new_file(File.basename(relative_path))
  app_target.resources_build_phase.add_file_reference(file_ref, true)
end

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  end
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app_target, test_target, launch_target: true)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save
puts "Generated #{PROJECT_PATH}"
