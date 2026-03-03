#!/bin/bash
# ─────────────────────────────────────────────────────────────
# DictationApp Installation Test Suite
# Self-contained bash tests with zero external dependencies.
#
# Usage:
#   ./tests/test_install.sh              # full suite
#   ./tests/test_install.sh --offline    # skip network tests
#   ./tests/test_install.sh --filter "preflight*"  # run subset
#   ./tests/test_install.sh --verbose    # show command output
#   ./tests/test_install.sh --smoke      # include app launch test
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ── Resolve repo root ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── CLI flags ───────────────────────────────────────────────
OFFLINE=false
VERBOSE=false
SMOKE=false
FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline)  OFFLINE=true; shift ;;
        --verbose)  VERBOSE=true; shift ;;
        --smoke)    SMOKE=true; shift ;;
        --filter)   FILTER="$2"; shift 2 ;;
        --filter=*) FILTER="${1#--filter=}"; shift ;;
        -h|--help)
            echo "Usage: $0 [--offline] [--verbose] [--smoke] [--filter PATTERN]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Minimal test framework ─────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_COUNT=0
FAILURES=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_verbose() {
    if $VERBOSE; then
        echo -e "  ${CYAN}|${NC} $*"
    fi
}

# Check if a test name matches the --filter glob pattern
matches_filter() {
    local name="$1"
    if [[ -z "$FILTER" ]]; then
        return 0
    fi
    # shellcheck disable=SC2254
    case "$name" in
        $FILTER) return 0 ;;
    esac
    return 1
}

run_test() {
    local name="$1"
    local fn="$2"

    if ! matches_filter "$name"; then
        return 0
    fi

    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    printf "  %-55s " "$name"

    # Capture output from subshell
    local output exit_code
    output="$( (set -e; "$fn") 2>&1)" && exit_code=0 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
        log_verbose "$output"
    elif [[ $exit_code -eq 2 ]]; then
        echo -e "${YELLOW}[SKIP]${NC} $output"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILURES="${FAILURES}\n  ${RED}FAIL${NC}: $name\n    $output\n"
        if $VERBOSE; then
            echo -e "    $output"
        fi
    fi
}

# Skip helper — call from inside a test function to skip it.
# Usage: skip "reason" — exits with code 2.
skip() { echo "$1"; exit 2; }

# Assert helpers
assert_eq() {
    if [[ "$1" != "$2" ]]; then
        echo "expected '$2', got '$1'"; return 1
    fi
}

assert_contains() {
    if [[ "$1" != *"$2"* ]]; then
        echo "output does not contain '$2'"; return 1
    fi
}

assert_file_exists() {
    if [[ ! -f "$1" ]]; then
        echo "file not found: $1"; return 1
    fi
}

assert_dir_exists() {
    if [[ ! -d "$1" ]]; then
        echo "directory not found: $1"; return 1
    fi
}

print_section() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "  ────────────────────────────────────────────────────────"
}

print_summary() {
    echo ""
    echo "  ════════════════════════════════════════════════════════"
    echo -e "  ${BOLD}Results:${NC} ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}, ${YELLOW}$SKIP_COUNT skipped${NC} / $TOTAL_COUNT total"

    if [[ -n "$FAILURES" ]]; then
        echo ""
        echo -e "${BOLD}  Failures:${NC}"
        echo -e "$FAILURES"
    fi

    echo "  ════════════════════════════════════════════════════════"
}

# ── Mock helpers for Section A ──────────────────────────────

# Create a temp directory with mock commands on PATH.
# Usage: MOCK_DIR=$(setup_mock_env) ; export PATH="$MOCK_DIR:$PATH"
setup_mock_env() {
    local dir
    dir="$(mktemp -d)"

    # Default: all commands succeed with plausible output
    _write_mock "$dir/sw_vers"        'echo "14.5"'
    _write_mock "$dir/xcode-select"   'exit 0'
    _write_mock "$dir/xcodebuild"     '
        case "$1" in
            -version) echo "Xcode 15.4" ;;
            -checkFirstLaunchStatus) exit 0 ;;
            *) exit 0 ;;
        esac'
    _write_mock "$dir/xattr"          'exit 0'
    _write_mock "$dir/codesign"       'exit 0'
    _write_mock "$dir/open"           'exit 0'
    # No mocks for cp/rm — install.sh is patched to use FakeApplications,
    # so real cp/rm operate safely on temp directories.

    echo "$dir"
}

_write_mock() {
    local path="$1" body="$2"
    cat > "$path" <<MOCK
#!/bin/bash
$body
MOCK
    chmod +x "$path"
}

# Create minimal fake project structure that install.sh expects
setup_fake_project() {
    local dir
    dir="$(mktemp -d)"
    mkdir -p "$dir/DictationApp/DictationApp.xcodeproj"
    mkdir -p "$dir/DictationApp"
    # Create a dummy entitlements file
    cat > "$dir/DictationApp/DictationApp.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
PLIST
    # Copy install.sh
    cp "$REPO_ROOT/install.sh" "$dir/install.sh"
    chmod +x "$dir/install.sh"
    echo "$dir"
}

# Run install.sh in a sandboxed env. Returns its stdout+stderr and exit code.
# Args: $1=mock_dir $2=project_dir [extra env setup via caller's PATH]
run_install_sandboxed() {
    local mock_dir="$1" project_dir="$2"
    (
        export PATH="$mock_dir:$PATH"
        cd "$project_dir"
        # Make xcodebuild mock produce a fake .app on build
        mkdir -p build/Build/Products/Release/DictationApp.app/Contents/MacOS
        echo "fake" > build/Build/Products/Release/DictationApp.app/Contents/MacOS/DictationApp
        # Redirect /Applications writes to temp
        export HOME="$project_dir"
        # Patch install.sh to install to a local dir instead of /Applications
        sed 's|/Applications|'"$project_dir"'/FakeApplications|g' install.sh > install_test.sh
        chmod +x install_test.sh
        mkdir -p "$project_dir/FakeApplications"
        bash install_test.sh 2>&1
    )
}

# ════════════════════════════════════════════════════════════
# Section A: Pre-Flight Validation (mocked, no Xcode needed)
# ════════════════════════════════════════════════════════════

test_preflight_macos_version_too_old() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    # Override sw_vers to return macOS 13
    _write_mock "$mock_dir/sw_vers" 'echo "13.6.1"'

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)" && return 1
    assert_contains "$output" "macOS 14"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_macos_version_exactly_14() {
    local mock_dir project_dir
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    _write_mock "$mock_dir/sw_vers" 'echo "14.0"'

    run_install_sandboxed "$mock_dir" "$project_dir" >/dev/null
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_macos_version_15() {
    local mock_dir project_dir
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    _write_mock "$mock_dir/sw_vers" 'echo "15.1"'

    run_install_sandboxed "$mock_dir" "$project_dir" >/dev/null
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_xcode_not_installed() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    _write_mock "$mock_dir/xcode-select" 'exit 1'

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)" && return 1
    assert_contains "$output" "Xcode is not installed"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_xcode_cli_tools_only() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    # xcode-select works but xcodebuild -version fails
    _write_mock "$mock_dir/xcodebuild" '
        case "$1" in
            -version) exit 1 ;;
            *) exit 0 ;;
        esac'

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)" && return 1
    assert_contains "$output" "full Xcode is required"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_xcode_license_not_accepted() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    _write_mock "$mock_dir/xcodebuild" '
        case "$1" in
            -version) echo "Xcode 15.4" ;;
            -checkFirstLaunchStatus) exit 1 ;;
            *) exit 0 ;;
        esac'

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)" && return 1
    assert_contains "$output" "license"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_missing_project_directory() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    # Remove the xcodeproj
    rm -rf "$project_dir/DictationApp/DictationApp.xcodeproj"

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)" && return 1
    assert_contains "$output" "Cannot find"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_all_checks_pass() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)"
    # Strip ANSI escape codes before checking
    local clean
    clean="$(echo "$output" | sed $'s/\033\\[[0-9;]*m//g')"
    assert_contains "$clean" "Installation complete"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_build_failure() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"

    # Run without creating the fake .app -- override run to not create it
    output="$(
        export PATH="$mock_dir:$PATH"
        cd "$project_dir"
        # No fake .app -- xcodebuild mock succeeds but produces nothing
        sed 's|/Applications|'"$project_dir"'/FakeApplications|g' install.sh > install_test.sh
        chmod +x install_test.sh
        mkdir -p "$project_dir/FakeApplications"
        bash install_test.sh 2>&1
    )" && return 1
    assert_contains "$output" "not found"
    rm -rf "$mock_dir" "$project_dir"
}

test_preflight_existing_app_replaced() {
    local mock_dir project_dir output
    mock_dir="$(setup_mock_env)"
    project_dir="$(setup_fake_project)"
    # Pre-create existing app in FakeApplications
    mkdir -p "$project_dir/FakeApplications/DictationApp.app"

    output="$(run_install_sandboxed "$mock_dir" "$project_dir" 2>&1)"
    assert_contains "$output" "replacing"
    rm -rf "$mock_dir" "$project_dir"
}

# ════════════════════════════════════════════════════════════
# Section B: Post-Build Bundle Verification
# ════════════════════════════════════════════════════════════

# Find a built .app bundle (check common locations)
find_built_app() {
    local candidates=(
        "$REPO_ROOT/build/Build/Products/Release/DictationApp.app"
        "/Applications/DictationApp.app"
    )
    for c in "${candidates[@]}"; do
        if [[ -d "$c" ]]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

test_bundle_info_plist() {
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"
    local plist="$app_path/Contents/Info.plist"

    assert_file_exists "$plist"
    # Valid XML
    plutil -lint "$plist" >/dev/null 2>&1 || { echo "Info.plist is not valid XML"; return 1; }
    # Required keys
    local keys=("LSUIElement" "NSMicrophoneUsageDescription" "CFBundleExecutable" "CFBundleIdentifier")
    for key in "${keys[@]}"; do
        if ! /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
            echo "Missing key: $key"; return 1
        fi
    done
}

test_bundle_executable() {
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"
    local exe="$app_path/Contents/MacOS/DictationApp"

    assert_file_exists "$exe"
    [[ -x "$exe" ]] || { echo "Binary is not executable"; return 1; }
    file "$exe" | grep -q "Mach-O" || { echo "Not a Mach-O binary"; return 1; }
}

test_bundle_resources() {
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"

    assert_dir_exists "$app_path/Contents/Resources"
}

test_bundle_codesign() {
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"

    codesign --verify --deep --strict "$app_path" 2>/dev/null || {
        skip "App is not ad-hoc signed (run install.sh to sign with entitlements)"
    }
}

test_bundle_entitlements() {
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"

    # Entitlements are only embedded after ad-hoc signing with --entitlements flag
    local ent
    ent="$(codesign -d --entitlements - "$app_path" 2>&1)" || skip "Cannot read entitlements"

    echo "$ent" | grep -q "audio-input" || skip "No entitlements embedded (run install.sh to ad-hoc sign)"
    echo "$ent" | grep -q "apple-events" || { echo "Missing apple-events entitlement"; return 1; }
}

test_bundle_frameworks() {
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"
    local exe="$app_path/Contents/MacOS/DictationApp"

    [[ -f "$exe" ]] || skip "No executable found"
    local linked
    linked="$(otool -L "$exe" 2>/dev/null)" || skip "otool not available"

    echo "$linked" | grep -q "AppKit" || { echo "AppKit not linked"; return 1; }
    echo "$linked" | grep -q "Foundation" || { echo "Foundation not linked"; return 1; }
}

test_bundle_smoke_launch() {
    $SMOKE || skip "Pass --smoke to enable"
    local app_path
    app_path="$(find_built_app)" || skip "No built .app found"

    local exe="$app_path/Contents/MacOS/DictationApp"
    [[ -x "$exe" ]] || skip "Executable not found"

    # Launch, wait 3s, check it's running, then kill it
    "$exe" &
    local pid=$!
    sleep 3
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    else
        echo "App exited within 3 seconds"; return 1
    fi
}

# ════════════════════════════════════════════════════════════
# Section C: Download & Install Path (network required)
# ════════════════════════════════════════════════════════════

GITHUB_REPO="justindeisler/dictation-app"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO/releases/latest"

test_download_release_reachable() {
    $OFFLINE && skip "Offline mode"
    local http_code
    http_code="$(curl -s -o /dev/null -w '%{http_code}' "$GITHUB_API")"
    [[ "$http_code" == "200" ]] || { echo "GitHub API returned HTTP $http_code"; return 1; }
}

test_download_asset_exists() {
    $OFFLINE && skip "Offline mode"
    local response
    response="$(curl -s "$GITHUB_API")"
    echo "$response" | grep -q "DictationApp-macOS.zip" || {
        echo "DictationApp-macOS.zip not found in latest release assets"
        return 1
    }
}

test_download_and_unzip() {
    $OFFLINE && skip "Offline mode"
    local tmpdir
    tmpdir="$(mktemp -d)"

    # Get download URL from API
    local url
    url="$(curl -s "$GITHUB_API" | grep -o '"browser_download_url":[[:space:]]*"[^"]*DictationApp-macOS.zip"' | grep -o 'https://[^"]*')"
    [[ -n "$url" ]] || { echo "Could not find download URL"; rm -rf "$tmpdir"; return 1; }

    curl -sL "$url" -o "$tmpdir/DictationApp-macOS.zip" || { echo "Download failed"; rm -rf "$tmpdir"; return 1; }
    unzip -q "$tmpdir/DictationApp-macOS.zip" -d "$tmpdir/out" || { echo "Unzip failed"; rm -rf "$tmpdir"; return 1; }
    assert_dir_exists "$tmpdir/out/DictationApp.app"
    rm -rf "$tmpdir"
}

test_download_bundle_integrity() {
    $OFFLINE && skip "Offline mode"
    local tmpdir
    tmpdir="$(mktemp -d)"

    local url
    url="$(curl -s "$GITHUB_API" | grep -o '"browser_download_url":[[:space:]]*"[^"]*DictationApp-macOS.zip"' | grep -o 'https://[^"]*')"
    [[ -n "$url" ]] || { echo "Could not find download URL"; rm -rf "$tmpdir"; return 1; }

    curl -sL "$url" -o "$tmpdir/DictationApp-macOS.zip"
    unzip -q "$tmpdir/DictationApp-macOS.zip" -d "$tmpdir/out"

    local app="$tmpdir/out/DictationApp.app"
    assert_dir_exists "$app"
    assert_file_exists "$app/Contents/Info.plist"
    plutil -lint "$app/Contents/Info.plist" >/dev/null 2>&1 || { echo "Invalid Info.plist"; rm -rf "$tmpdir"; return 1; }
    assert_file_exists "$app/Contents/MacOS/DictationApp"
    assert_dir_exists "$app/Contents/Resources"
    rm -rf "$tmpdir"
}

test_download_codesign_valid() {
    $OFFLINE && skip "Offline mode"
    local tmpdir
    tmpdir="$(mktemp -d)"

    local url
    url="$(curl -s "$GITHUB_API" | grep -o '"browser_download_url":[[:space:]]*"[^"]*DictationApp-macOS.zip"' | grep -o 'https://[^"]*')"
    [[ -n "$url" ]] || { echo "Could not find download URL"; rm -rf "$tmpdir"; return 1; }

    curl -sL "$url" -o "$tmpdir/DictationApp-macOS.zip"
    unzip -q "$tmpdir/DictationApp-macOS.zip" -d "$tmpdir/out"

    codesign --verify --deep --strict "$tmpdir/out/DictationApp.app" 2>/dev/null || {
        echo "Code signature invalid on downloaded app"
        rm -rf "$tmpdir"
        return 1
    }
    rm -rf "$tmpdir"
}

# ════════════════════════════════════════════════════════════
# Section D: Environment Compatibility
# ════════════════════════════════════════════════════════════

test_env_macos_version() {
    local version major
    version="$(sw_vers -productVersion 2>/dev/null)" || skip "sw_vers not available"
    major="$(echo "$version" | cut -d. -f1)"
    [[ "$major" -ge 14 ]] || { echo "macOS $version < 14 required"; return 1; }
}

test_env_disk_space() {
    local available_kb
    available_kb="$(df -k "$REPO_ROOT" | awk 'NR==2 {print $4}')"
    local required_kb=$((1024 * 1024))  # 1GB
    [[ "$available_kb" -ge "$required_kb" ]] || {
        echo "Only $((available_kb / 1024))MB available, need 1024MB"
        return 1
    }
}

test_env_entitlements_file() {
    local ent="$REPO_ROOT/DictationApp/DictationApp.entitlements"
    assert_file_exists "$ent"
    plutil -lint "$ent" >/dev/null 2>&1 || { echo "Entitlements not valid XML"; return 1; }
    grep -q "audio-input" "$ent" || { echo "Missing audio-input key"; return 1; }
    grep -q "apple-events" "$ent" || { echo "Missing apple-events key"; return 1; }
}

test_env_install_script_executable() {
    local script="$REPO_ROOT/install.sh"
    assert_file_exists "$script"
    [[ -x "$script" ]] || { echo "install.sh is not executable"; return 1; }
}

test_env_install_script_syntax() {
    bash -n "$REPO_ROOT/install.sh" 2>&1 || { echo "Syntax error in install.sh"; return 1; }
}

test_env_permissions_documented() {
    local readme="$REPO_ROOT/README.md"
    assert_file_exists "$readme"
    grep -qi "microphone" "$readme" || { echo "README does not mention Microphone"; return 1; }
    grep -qi "accessibility" "$readme" || { echo "README does not mention Accessibility"; return 1; }
}

# ════════════════════════════════════════════════════════════
# Run all tests
# ════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}DictationApp Installation Test Suite${NC}"
echo "  ════════════════════════════════════════════════════════"

print_section "Section A: Pre-Flight Validation (mocked)"
run_test "preflight_macos_version_too_old"      test_preflight_macos_version_too_old
run_test "preflight_macos_version_exactly_14"    test_preflight_macos_version_exactly_14
run_test "preflight_macos_version_15"            test_preflight_macos_version_15
run_test "preflight_xcode_not_installed"         test_preflight_xcode_not_installed
run_test "preflight_xcode_cli_tools_only"        test_preflight_xcode_cli_tools_only
run_test "preflight_xcode_license_not_accepted"  test_preflight_xcode_license_not_accepted
run_test "preflight_missing_project_directory"   test_preflight_missing_project_directory
run_test "preflight_all_checks_pass"             test_preflight_all_checks_pass
run_test "preflight_build_failure"               test_preflight_build_failure
run_test "preflight_existing_app_replaced"       test_preflight_existing_app_replaced

print_section "Section B: Post-Build Bundle Verification"
run_test "bundle_info_plist"    test_bundle_info_plist
run_test "bundle_executable"    test_bundle_executable
run_test "bundle_resources"     test_bundle_resources
run_test "bundle_codesign"      test_bundle_codesign
run_test "bundle_entitlements"  test_bundle_entitlements
run_test "bundle_frameworks"    test_bundle_frameworks
run_test "bundle_smoke_launch"  test_bundle_smoke_launch

print_section "Section C: Download & Install Path"
run_test "download_release_reachable"  test_download_release_reachable
run_test "download_asset_exists"       test_download_asset_exists
run_test "download_and_unzip"          test_download_and_unzip
run_test "download_bundle_integrity"   test_download_bundle_integrity
run_test "download_codesign_valid"     test_download_codesign_valid

print_section "Section D: Environment Compatibility"
run_test "env_macos_version"            test_env_macos_version
run_test "env_disk_space"               test_env_disk_space
run_test "env_entitlements_file"        test_env_entitlements_file
run_test "env_install_script_executable" test_env_install_script_executable
run_test "env_install_script_syntax"    test_env_install_script_syntax
run_test "env_permissions_documented"   test_env_permissions_documented

print_summary

# Exit with failure code if any tests failed
[[ "$FAIL_COUNT" -eq 0 ]]
