THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:14.5:13.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BlueeMods

BlueeMods_FILES = BlueeMods/Tweak.x BlueeMods/BlueeModsWindow.mm
BlueeMods_CFLAGS = -fobjc-arc
BlueeMods_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
