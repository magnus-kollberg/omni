SCHEME = omni
APP_NAME = omni
BUILD_TYPE = Release

build:
	xcodebuild -scheme $(SCHEME) -configuration $(BUILD_TYPE) -sdk iphoneos

deploy:
	$(eval BUILD_DIR := $(shell xcodebuild -scheme $(SCHEME) -showBuildSettings | grep -E "^ *BUILD_DIR =" | awk -F' = ' '{print $$2}'))
	@APP_PATH="$(BUILD_DIR)/$(BUILD_TYPE)-iphoneos/$(APP_NAME).app"; \
	if [ -d "$$APP_PATH" ]; then \
		ios-deploy --bundle "$$APP_PATH"; \
	else \
		echo "App bundle not found at $$APP_PATH"; \
	fi

launch:
	$(eval BUILD_DIR := $(shell xcodebuild -scheme $(SCHEME) -showBuildSettings | grep -E "^ *BUILD_DIR =" | awk -F' = ' '{print $$2}'))
	@APP_PATH="$(BUILD_DIR)/$(BUILD_TYPE)-iphoneos/$(APP_NAME).app"; \
        if [ -d "$$APP_PATH" ]; then \
                ios-deploy --bundle "$$APP_PATH" --justlaunch --no-wifi; \
        else \
                echo "App not found at $$APP_PATH"; \
        fi

logs:
	$(eval BUILD_DIR := $(shell xcodebuild -scheme $(SCHEME) -showBuildSettings | grep -E "^ *BUILD_DIR =" | awk -F' = ' '{print $$2}'))
	@APP_PATH="$(BUILD_DIR)/$(BUILD_TYPE)-iphoneos/$(APP_NAME).app"; \
	if [ -d "$$APP_PATH" ]; then \
		ios-deploy --bundle "$$APP_PATH" --debug; \
	else \
		echo "App not found at $$APP_PATH"; \
	fi

