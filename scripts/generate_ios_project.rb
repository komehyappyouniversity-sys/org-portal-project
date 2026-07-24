#!/usr/bin/env ruby

require "xcodeproj"
require "pathname"

repo_root = Pathname.new(__dir__).parent
ios_root = repo_root.join("NextApp", "iOS", "OrgPortalNext")
project_path = ios_root.join("OrgPortalNext.xcodeproj")

project = Xcodeproj::Project.new(project_path.to_s)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2620"
project.root_object.attributes["LastUpgradeCheck"] = "2620"

def configure_target(target, product_bundle_identifier: nil)
  target.build_configurations.each do |configuration|
    settings = configuration.build_settings
    settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
    settings["SWIFT_VERSION"] = "6.0"
    settings["GENERATE_INFOPLIST_FILE"] = "YES" unless target.product_type == "com.apple.product-type.application"
    settings["CODE_SIGN_STYLE"] = "Automatic"
    settings["ENABLE_USER_SCRIPT_SANDBOXING"] = "YES"
    settings["PRODUCT_BUNDLE_IDENTIFIER"] = product_bundle_identifier if product_bundle_identifier
    settings["DEVELOPMENT_TEAM"] = ""
  end
end

def add_swift_files(project, target, group_name, directory)
  group = project.main_group.new_group(group_name.tr("/", " · "), group_name)
  Dir.glob(directory.join("**", "*.swift").to_s).sort.each do |path|
    relative = Pathname.new(path).relative_path_from(directory).to_s
    file = group.new_file(relative)
    target.source_build_phase.add_file_reference(file)
  end
end

def link(target, dependency)
  target.add_dependency(dependency)
  target.frameworks_build_phase.add_file_reference(dependency.product_reference)
end

def embed(dependency, phase)
  build_file = phase.add_file_reference(dependency.product_reference, true)
  build_file.settings = {
    "ATTRIBUTES" => ["CodeSignOnCopy", "RemoveHeadersOnCopy"]
  }
end

platform = :ios
deployment_target = "17.0"

targets = {}
{
  "Model" => "Core/Model",
  "DesignSystem" => "Core/DesignSystem",
  "Navigation" => "Core/Navigation",
  "Session" => "Core/Session",
  "DataLayer" => "Core/DataLayer",
  "Notifications" => "Core/Notifications",
  "Testing" => "Core/Testing",
  "FeatureTools" => "Feature/Tools"
}.each do |name, relative_path|
  target = project.new_target(:framework, name, platform, deployment_target)
  configure_target(target, product_bundle_identifier: "org.nagaoka.blog.k100.member.next.#{name.downcase}")
  add_swift_files(project, target, relative_path, ios_root.join(relative_path))
  targets[name] = target
end

link(targets["Navigation"], targets["DesignSystem"])
link(targets["Session"], targets["Model"])
link(targets["DataLayer"], targets["Model"])
link(targets["Notifications"], targets["Model"])
link(targets["Testing"], targets["Model"])
link(targets["FeatureTools"], targets["Model"])
link(targets["FeatureTools"], targets["DesignSystem"])
link(targets["FeatureTools"], targets["DataLayer"])
link(targets["FeatureTools"], targets["Notifications"])

app = project.new_target(:application, "OrgPortalNext", platform, deployment_target)
configure_target(app, product_bundle_identifier: "org.nagaoka.blog.k100.member.next")
app.build_configurations.each do |configuration|
  settings = configuration.build_settings
  settings["GENERATE_INFOPLIST_FILE"] = "NO"
  settings["INFOPLIST_FILE"] = "App/Info.plist"
  settings["PRODUCT_NAME"] = "OrgPortalNext"
  settings["MARKETING_VERSION"] = "1.0"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = ""
  settings["FIREBASE_PROJECT_ID"] = "demo-org-portal-next"
end
add_swift_files(project, app, "App", ios_root.join("App"))
resources_group = project.main_group.new_group("App Resources", "App/Resources")
Dir.glob(ios_root.join("App", "Resources", "*").to_s).sort.each do |path|
  file = resources_group.new_file(Pathname.new(path).basename.to_s)
  app.resources_build_phase.add_file_reference(file)
end
embed_frameworks_phase = app.new_copy_files_build_phase("Embed Frameworks")
embed_frameworks_phase.dst_subfolder_spec = "10"
%w[Model DesignSystem Navigation Session DataLayer Notifications FeatureTools].each do |name|
  link(app, targets[name])
  embed(targets[name], embed_frameworks_phase)
end

{
  "ModelTests" => ["Tests/ModelTests", ["Model"]],
  "DataLayerTests" => ["Tests/DataLayerTests", ["DataLayer", "Model"]],
  "FeatureToolsTests" => ["Tests/FeatureToolsTests", ["FeatureTools", "Model"]]
}.each do |name, (relative_path, dependencies)|
  test_target = project.new_target(:unit_test_bundle, name, platform, deployment_target)
  configure_target(test_target, product_bundle_identifier: "org.nagaoka.blog.k100.member.next.tests.#{name.downcase}")
  add_swift_files(project, test_target, relative_path, ios_root.join(relative_path))
  dependencies.each { |dependency| link(test_target, targets.fetch(dependency)) }
end

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
project.targets.select { |target| target.product_type == "com.apple.product-type.bundle.unit-test" }.each do |target|
  scheme.add_test_target(target)
end
scheme.save_as(project_path.to_s, "OrgPortalNext", true)

project.recreate_user_schemes
project.save

puts "Generated #{project_path}"
