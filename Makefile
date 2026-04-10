BUNDLE_NAME = QLMarkdownViewer
APP = $(BUNDLE_NAME).app
APPEX = QLMarkdownPreview.appex
BUILD_DIR = build
INSTALL_DIR = $(HOME)/Applications

# Host app source
HOST_SRC = src/HostApp.swift

# Extension sources (shared MarkdownParser + preview controller)
EXT_SRC = src/PreviewViewController.swift src/MarkdownParser.swift

.PHONY: build install uninstall clean test

build: clean
	@echo "Building $(APP) with embedded Quick Look extension..."

	# Create app bundle structure
	@mkdir -p $(BUILD_DIR)/$(APP)/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(APP)/Contents/Resources
	@mkdir -p $(BUILD_DIR)/$(APP)/Contents/PlugIns/$(APPEX)/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(APP)/Contents/PlugIns/$(APPEX)/Contents/Resources

	# Build host app
	swiftc -O -o $(BUILD_DIR)/$(APP)/Contents/MacOS/$(BUNDLE_NAME) \
		-framework AppKit \
		$(HOST_SRC)

	# Build extension as XPC service (no main entry point)
	swiftc -O -parse-as-library -module-name QLMarkdownPreview \
		-o $(BUILD_DIR)/$(APP)/Contents/PlugIns/$(APPEX)/Contents/MacOS/QLMarkdownPreview \
		-framework Cocoa -framework Quartz \
		-Xlinker -e -Xlinker _NSExtensionMain \
		-application-extension \
		$(EXT_SRC)

	# Copy Info.plist files
	@cp resources/HostApp-Info.plist $(BUILD_DIR)/$(APP)/Contents/Info.plist
	@cp resources/Extension-Info.plist $(BUILD_DIR)/$(APP)/Contents/PlugIns/$(APPEX)/Contents/Info.plist

	# Copy CSS to extension resources
	@cp resources/style.css $(BUILD_DIR)/$(APP)/Contents/PlugIns/$(APPEX)/Contents/Resources/

	# Code sign extension first, then app
	@codesign --force --sign - \
		--entitlements resources/Extension.entitlements \
		$(BUILD_DIR)/$(APP)/Contents/PlugIns/$(APPEX)
	@codesign --force --sign - \
		$(BUILD_DIR)/$(APP)

	@echo "Build complete: $(BUILD_DIR)/$(APP)"

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/$(APP)
	@cp -R $(BUILD_DIR)/$(APP) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/$(APP)"
	@echo ""
	@echo "To activate: open the app once, then enable in"
	@echo "  System Settings > General > Login Items & Extensions > Quick Look"

uninstall:
	@echo "Uninstalling $(APP)..."
	@rm -rf $(INSTALL_DIR)/$(APP)
	@echo "Uninstalled. You may need to restart Finder."

clean:
	@rm -rf $(BUILD_DIR)

test: install
	@echo "Opening app to register extension..."
	@open $(INSTALL_DIR)/$(APP)
	@sleep 2
	@echo "Testing Quick Look preview..."
	@qlmanage -p test/sample.md
