#import <UIKit/UIKit.h>
#import "BlueeModsWindow.h"

// Hook into the app's root view controller to inject our overlay
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Only inject once into the root view controller
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [BlueeModsWindow install];
        });
    });
}

%end
