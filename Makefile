THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:16.5:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BlueeMods

BlueeMods_FILES = BlueeMods/Tweak.x BlueeMods/BlueeModsWindow.mm
BlueeMods_CFLAGS = -fobjc-arc
BlueeMods_CCFLAGS = -fobjc-arc -std=gnu++14
BlueeMods_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
