#!/usr/bin/env bash
# Idempotently registers Cypriot Keyboard/Onboarding/**/*.swift in the app target,
# and Cypriot KeyboardTests/Onboarding*.swift in the test target.
# Uses xcodeproj gem (installed under user gems) and adjusts GEM_PATH if needed.
#
# Run from the project root (the directory containing 'Cypriot Keyboard.xcodeproj').

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ_DIR="$ROOT/Cypriot Keyboard.xcodeproj"
ONB_DIR="$ROOT/Cypriot Keyboard/Onboarding"
TEST_DIR="$ROOT/Cypriot KeyboardTests"

# Pick up user-installed xcodeproj gem
USER_GEM_DIR="$(ruby -e 'puts Gem.user_dir' 2>/dev/null || echo "")"
if [ -n "$USER_GEM_DIR" ] && [ -d "$USER_GEM_DIR/gems" ]; then
    export GEM_PATH="$USER_GEM_DIR:${GEM_PATH:-}"
fi

if ! ruby -e 'require "xcodeproj"' 2>/dev/null; then
    echo "ERROR: xcodeproj gem not loadable. Try: gem install xcodeproj --user-install" >&2
    exit 1
fi

PBXPROJ_DIR="$PBXPROJ_DIR" ONB_DIR="$ONB_DIR" TEST_DIR="$TEST_DIR" ROOT="$ROOT" \
    ruby <<'RUBY'
require "xcodeproj"

project_path = ENV["PBXPROJ_DIR"]
onb_dir = ENV["ONB_DIR"]
test_dir = ENV["TEST_DIR"]
root = ENV["ROOT"]

project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == "Cypriot Keyboard" }
abort "App target 'Cypriot Keyboard' not found" if app_target.nil?

test_target = project.targets.find { |t| t.name == "Cypriot KeyboardTests" }
abort "Test target 'Cypriot KeyboardTests' not found" if test_target.nil?

app_main_group = project.main_group["Cypriot Keyboard"]
abort "Main group 'Cypriot Keyboard' not found" if app_main_group.nil?

# Ensure Onboarding group (and any subgroups like Components) exist as a hierarchy.
def ensure_group(parent, segments)
    return parent if segments.empty?
    head, *rest = segments
    child = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == head }
    child ||= parent.new_group(head, head)
    ensure_group(child, rest)
end

# All swift files under Onboarding/
Dir.glob(File.join(onb_dir, "**/*.swift")).sort.each do |abs_path|
    rel_under_onb = abs_path.sub(onb_dir + "/", "")
    segments = File.dirname(rel_under_onb).split("/").reject { |s| s == "." }
    onb_root = ensure_group(app_main_group, ["Onboarding"])
    container_group = ensure_group(onb_root, segments)

    basename = File.basename(abs_path)
    next if container_group.children.any? { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) && c.display_name == basename }

    ref = container_group.new_file(abs_path)
    app_target.add_file_references([ref])
    puts "added (app)   #{rel_under_onb}"
end

# Test files: anything in Cypriot KeyboardTests/ that starts with Onboarding
test_main_group = project.main_group["Cypriot KeyboardTests"]
abort "Test group 'Cypriot KeyboardTests' not found" if test_main_group.nil?

Dir.glob(File.join(test_dir, "Onboarding*.swift")).sort.each do |abs_path|
    basename = File.basename(abs_path)
    next if test_main_group.children.any? { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) && c.display_name == basename }
    ref = test_main_group.new_file(abs_path)
    test_target.add_file_references([ref])
    puts "added (test)  #{basename}"
end

project.save
RUBY
