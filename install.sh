#!/bin/bash
set -e

# ─────────────────────────────────────────────
# DictationApp Installer
# Builds from source and copies to /Applications
# ─────────────────────────────────────────────

APP_NAME="DictationApp"
PROJECT_DIR="DictationApp"
BUILD_DIR="build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BOLD}==>${NC} $1"; }
success() { echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}==>${NC} $1"; }
error()   { echo -e "${RED}Error:${NC} $1"; exit 1; }

# ── Check: macOS version ──────────────────────
info "Checking macOS version..."
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then
    error "macOS 14 (Sonoma) or later is required. You have macOS $MACOS_VERSION."
fi
success "macOS $MACOS_VERSION — OK"

# ── Check: Xcode installed ────────────────────
info "Checking for Xcode..."
if ! xcode-select -p &>/dev/null; then
    error "Xcode is not installed. Please install it from the Mac App Store and run this script again."
fi

# Verify xcodebuild works (catches case where CLI tools exist but full Xcode doesn't)
if ! xcodebuild -version &>/dev/null; then
    error "Xcode command-line tools found but full Xcode is required. Please install Xcode from the Mac App Store."
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
success "$XCODE_VERSION — OK"

# ── Check: license accepted ───────────────────
if ! xcodebuild -checkFirstLaunchStatus &>/dev/null; then
    warn "Xcode license has not been accepted. Opening Xcode to accept..."
    warn "Please accept the license, then close Xcode and re-run this script."
    open -a Xcode
    exit 1
fi

# ── Navigate to project directory ─────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "$PROJECT_DIR/$APP_NAME.xcodeproj" ]; then
    error "Cannot find $PROJECT_DIR/$APP_NAME.xcodeproj. Make sure you're running this script from the DictationApp repository root."
fi

# ── Build the app ─────────────────────────────
info "Building $APP_NAME (this may take a minute on first run)..."

xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    -derivedDataPath "$BUILD_DIR" \
    -quiet

BUILD_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$BUILD_APP" ]; then
    error "Build failed — $APP_NAME.app not found. Check the output above for errors."
fi

success "Build successful!"

# ── Ad-hoc sign with entitlements ────────────
info "Signing with entitlements..."
xattr -cr "$BUILD_APP"
codesign --force --sign - --entitlements "$PROJECT_DIR/$APP_NAME.entitlements" --deep "$BUILD_APP"
success "Signed!"

# ── Copy to /Applications ─────────────────────
info "Installing to /Applications..."

if [ -d "/Applications/$APP_NAME.app" ]; then
    warn "Existing $APP_NAME.app found in /Applications — replacing it."
    rm -rf "/Applications/$APP_NAME.app"
fi

cp -R "$BUILD_APP" "/Applications/$APP_NAME.app"
success "Installed to /Applications/$APP_NAME.app"

# ── Clean up build directory ──────────────────
info "Cleaning up build files..."
rm -rf "$BUILD_DIR"
success "Done!"

# ── Success message ───────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open $APP_NAME from /Applications or Spotlight (Cmd+Space)"
echo "  2. Click the menu bar icon and open Settings"
echo "  3. Paste your Groq API key (get one free at https://console.groq.com/keys)"
echo "  4. Grant Microphone and Accessibility permissions when prompted"
echo "  5. Press Option+Space to start dictating!"
echo ""
echo "For detailed setup instructions, see SETUP.md"
