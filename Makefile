PROJECT := Odak.xcodeproj
SCHEME := Odak
BUILD_DIR := build
APP := $(BUILD_DIR)/Build/Products/Release/Odak.app

.PHONY: project build run test clean

project:
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(BUILD_DIR) CODE_SIGN_IDENTITY=- build

run: build
	open "$(APP)"

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR) CODE_SIGN_IDENTITY=- test

clean:
	rm -rf $(BUILD_DIR) $(PROJECT)
