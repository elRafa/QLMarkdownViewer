BUNDLE_NAME = QLMarkdownViewer
BUNDLE = $(BUNDLE_NAME).qlgenerator
BUILD_DIR = build
INSTALL_DIR = $(HOME)/Library/QuickLook

SWIFT_FILES = src/MarkdownParser.swift src/GeneratePreviewForURL.swift src/GenerateThumbnailForURL.swift
C_FILES = src/main.c

SWIFT_FLAGS = -parse-as-library -O -module-name $(BUNDLE_NAME) -emit-library \
	-framework QuickLook -framework CoreServices -framework CoreFoundation

C_FLAGS = -framework CoreFoundation -framework CoreServices -framework QuickLook

.PHONY: build install uninstall clean test

build: clean
	@echo "Building $(BUNDLE)..."
	@mkdir -p $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(BUNDLE)/Contents/Resources

	# Compile Swift sources into a dynamic library
	swiftc $(SWIFT_FLAGS) \
		-o $(BUILD_DIR)/lib$(BUNDLE_NAME).dylib \
		$(SWIFT_FILES)

	# Compile C entry point and link with Swift library
	clang $(C_FLAGS) \
		-L$(BUILD_DIR) -l$(BUNDLE_NAME) \
		-Xlinker -rpath -Xlinker @loader_path \
		-bundle \
		-o $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/$(BUNDLE_NAME) \
		$(C_FILES)

	# Copy dylib into bundle
	@cp $(BUILD_DIR)/lib$(BUNDLE_NAME).dylib $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/

	# Copy resources
	@cp resources/Info.plist $(BUILD_DIR)/$(BUNDLE)/Contents/
	@cp resources/style.css $(BUILD_DIR)/$(BUNDLE)/Contents/Resources/

	@echo "Build complete: $(BUILD_DIR)/$(BUNDLE)"

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/$(BUNDLE)
	@cp -R $(BUILD_DIR)/$(BUNDLE) $(INSTALL_DIR)/
	@qlmanage -r 2>/dev/null || true
	@echo "Installed. Quick Look plugins reloaded."

uninstall:
	@echo "Uninstalling $(BUNDLE)..."
	@rm -rf $(INSTALL_DIR)/$(BUNDLE)
	@qlmanage -r 2>/dev/null || true
	@echo "Uninstalled."

clean:
	@rm -rf $(BUILD_DIR)

test: install
	@echo "Testing Quick Look preview..."
	@qlmanage -p test/sample.md
