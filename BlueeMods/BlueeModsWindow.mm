#import "BlueeModsWindow.h"
#import <QuartzCore/QuartzCore.h>

// ─── Item Model ───────────────────────────────────────────────────────────────
@interface ACItem : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *itemId;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, strong) NSString *tab;
+ (instancetype)name:(NSString *)name id:(NSString *)itemId cat:(NSString *)cat tab:(NSString *)tab;
@end

@implementation ACItem
+ (instancetype)name:(NSString *)name id:(NSString *)itemId cat:(NSString *)cat tab:(NSString *)tab {
    ACItem *i = [ACItem new];
    i.name = name; i.itemId = itemId; i.category = cat; i.tab = tab;
    return i;
}
@end

// ─── Colors ───────────────────────────────────────────────────────────────────
#define BG_COLOR        [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1]
#define SURFACE_COLOR   [UIColor colorWithRed:0.04 green:0.05 blue:0.10 alpha:1]
#define SURFACE2_COLOR  [UIColor colorWithRed:0.05 green:0.08 blue:0.15 alpha:1]
#define CYAN_COLOR      [UIColor colorWithRed:0.00 green:0.81 blue:1.00 alpha:1]
#define CYAN_DIM        [UIColor colorWithRed:0.00 green:0.81 blue:1.00 alpha:0.6]
#define CYAN_GLOW       [UIColor colorWithRed:0.00 green:0.63 blue:1.00 alpha:0.15]
#define BORDER_COLOR    [UIColor colorWithRed:0.00 green:0.63 blue:1.00 alpha:0.18]
#define TEXT_COLOR      [UIColor colorWithRed:1 green:1 blue:1 alpha:0.9]
#define TEXT_DIM_COLOR  [UIColor colorWithRed:1 green:1 blue:1 alpha:0.4]

// ─── Item Card Cell ───────────────────────────────────────────────────────────
@interface ItemCardCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *idLabel;
@end

@implementation ItemCardCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = SURFACE_COLOR;
        self.contentView.layer.cornerRadius = 10;
        self.contentView.layer.borderWidth = 1;
        self.contentView.layer.borderColor = BORDER_COLOR.CGColor;
        self.contentView.clipsToBounds = YES;

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont boldSystemFontOfSize:12];
        _nameLabel.textColor = TEXT_COLOR;
        _nameLabel.numberOfLines = 2;
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _idLabel = [[UILabel alloc] init];
        _idLabel.font = [UIFont fontWithName:@"Courier New" size:9] ?: [UIFont systemFontOfSize:9];
        _idLabel.textColor = CYAN_DIM;
        _idLabel.numberOfLines = 1;
        _idLabel.adjustsFontSizeToFitWidth = YES;
        _idLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_nameLabel];
        [self.contentView addSubview:_idLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
            [_idLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
            [_idLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:8],
            [_idLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8],
        ]];
    }
    return self;
}

- (void)flashSpawn {
    [UIView animateWithDuration:0.1 animations:^{
        self.contentView.backgroundColor = CYAN_GLOW;
        self.contentView.layer.borderColor = CYAN_COLOR.CGColor;
    } completion:^(BOOL done) {
        [UIView animateWithDuration:0.4 animations:^{
            self.contentView.backgroundColor = SURFACE_COLOR;
            self.contentView.layer.borderColor = BORDER_COLOR.CGColor;
        }];
    }];
}
@end

// ─── Main Window ──────────────────────────────────────────────────────────────
@interface BlueeModsWindow () <UICollectionViewDelegate, UICollectionViewDataSource>

// Overlay window
@property (nonatomic, strong) UIWindow *overlayWindow;

// BMv1 button
@property (nonatomic, strong) UIButton *bmButton;
@property (nonatomic, strong) CALayer *sweepLayer;
@property (nonatomic, strong) NSTimer *radarTimer;
@property (nonatomic, strong) NSMutableArray *blipLayers;

// Menu panel
@property (nonatomic, strong) UIView *menuPanel;
@property (nonatomic, assign) BOOL menuVisible;

// Data
@property (nonatomic, strong) NSArray<ACItem *> *allItems;
@property (nonatomic, strong) NSArray<ACItem *> *filteredItems;
@property (nonatomic, strong) NSString *activeTab;
@property (nonatomic, strong) NSString *activeCat;
@property (nonatomic, assign) NSInteger qty;

// UI refs
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UITextField *qtyField;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIScrollView *catScrollView;
@property (nonatomic, strong) UIView *connDot;
@property (nonatomic, strong) UILabel *connLabel;

// Drag
@property (nonatomic, assign) CGPoint dragOffset;

// WebSocket
@property (nonatomic, strong) NSURLSessionWebSocketTask *wsTask;
@property (nonatomic, strong) NSURLSession *wsSession;

@end

@implementation BlueeModsWindow

+ (void)install {
    static BlueeModsWindow *instance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [[BlueeModsWindow alloc] init];
        [instance setup];
    });
}

- (void)setup {
    [self buildItemDatabase];
    self.activeTab = @"Weapons";
    self.activeCat = @"All";
    self.qty = 1;

    // Create a UIWindowScene-based window on iOS 13+
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s;
            break;
        }
    }

    _overlayWindow = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _overlayWindow.windowLevel = UIWindowLevelAlert + 100;
    _overlayWindow.backgroundColor = [UIColor clearColor];
    _overlayWindow.userInteractionEnabled = YES;
    _overlayWindow.hidden = NO;

    // Transparent root VC so touches pass through when menu is closed
    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    _overlayWindow.rootViewController = rootVC;

    [self buildBMButton];
    [self buildMenuPanel];
    [self filterItems];
    [self autoConnect];
}

// ─── Item Database ────────────────────────────────────────────────────────────
- (void)buildItemDatabase {
    self.allItems = @[
        // WEAPONS - Melee
        [ACItem name:@"Arm Bone"      id:@"arm_bone"       cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Baseball Bat"  id:@"baseball_bat"   cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Baton"         id:@"baton"          cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Bone"          id:@"bone"           cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Boomspear"     id:@"boomspear"      cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Crowbar"       id:@"crowbar"        cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Cube Pickaxe"  id:@"cube_pickaxe"   cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Drill"         id:@"drill"          cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Frying Pan"    id:@"frying_pan"     cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Golden Pickaxe" id:@"golden_pickaxe" cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Great Sword"   id:@"great_sword"    cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Hatchet"       id:@"hatchet"        cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Lance"         id:@"lance"          cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Ogre Hands"    id:@"ogre_hands"     cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Pickaxe"       id:@"pickaxe"        cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Spear"         id:@"spear"          cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Sword"         id:@"sword"          cat:@"Melee"      tab:@"Weapons"],
        [ACItem name:@"Stellar Swords" id:@"stellar_swords" cat:@"Melee"      tab:@"Weapons"],
        // WEAPONS - Ranged
        [ACItem name:@"Boomerang"     id:@"boomerang"      cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Crossbow"      id:@"crossbow"       cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Dragon Pistol" id:@"dragon_pistol"  cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Flamethrower"  id:@"flamethrower"   cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Golden Gun"    id:@"golden_gun"     cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Love Crossbow" id:@"love_crossbow"  cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Revolver"      id:@"revolver"       cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Shotgun"       id:@"shotgun"        cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Viper Shotgun" id:@"viper_shotgun"  cat:@"Ranged"     tab:@"Weapons"],
        [ACItem name:@"Arrow"         id:@"arrow"          cat:@"Ranged"     tab:@"Weapons"],
        // WEAPONS - Explosives
        [ACItem name:@"Dragon Rocket" id:@"dragon_rocket_launcher" cat:@"Explosives" tab:@"Weapons"],
        [ACItem name:@"Easter RPG"    id:@"easter_rpg"     cat:@"Explosives" tab:@"Weapons"],
        [ACItem name:@"SMSHR RPG"     id:@"smshr_rpg"      cat:@"Explosives" tab:@"Weapons"],
        [ACItem name:@"Grenade Launcher" id:@"grenade_launcher" cat:@"Explosives" tab:@"Weapons"],
        [ACItem name:@"Dynamite"      id:@"dynamite"       cat:@"Explosives" tab:@"Weapons"],
        [ACItem name:@"Flashbang"     id:@"flashbang"      cat:@"Explosives" tab:@"Weapons"],
        [ACItem name:@"Bone Shield"   id:@"bone_shield"    cat:@"Shields"    tab:@"Weapons"],
        // GADGETS
        [ACItem name:@"Axe"           id:@"axe"            cat:@"Tools"      tab:@"Gadgets"],
        [ACItem name:@"Alpha Blade"   id:@"alpha_blade"    cat:@"Tools"      tab:@"Gadgets"],
        [ACItem name:@"Balloon"       id:@"balloon"        cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Box"           id:@"box"            cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Box Fan"       id:@"box_fan"        cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Camera"        id:@"camera"         cat:@"Tools"      tab:@"Gadgets"],
        [ACItem name:@"Flare Gun"     id:@"flare_gun"      cat:@"Tools"      tab:@"Gadgets"],
        [ACItem name:@"Flashlight"    id:@"flashlight"     cat:@"Tools"      tab:@"Gadgets"],
        [ACItem name:@"Friend Launcher" id:@"friend_launcher" cat:@"Fun"     tab:@"Gadgets"],
        [ACItem name:@"Hand Jetpack"  id:@"handheld_jetpack" cat:@"Movement" tab:@"Gadgets"],
        [ACItem name:@"Heart Balloon" id:@"heart_balloon"  cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Heart Guns"    id:@"heart_guns"     cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Hookshot"      id:@"hookshot"       cat:@"Movement"   tab:@"Gadgets"],
        [ACItem name:@"Hover Board"   id:@"hoverboard"     cat:@"Movement"   tab:@"Gadgets"],
        [ACItem name:@"Mega Flashlight" id:@"mega_flashlight" cat:@"Tools"   tab:@"Gadgets"],
        [ACItem name:@"Money Gun"     id:@"money_gun"      cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Plunger"       id:@"plunger"        cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Pogo Stick"    id:@"pogo_stick"     cat:@"Movement"   tab:@"Gadgets"],
        [ACItem name:@"RoboMonke2000" id:@"robomonke2000"  cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Saddle"        id:@"saddle"         cat:@"Fun"        tab:@"Gadgets"],
        [ACItem name:@"Sticker Dispenser" id:@"sticker_dispenser" cat:@"Fun" tab:@"Gadgets"],
        [ACItem name:@"Tablet"        id:@"tablet"         cat:@"Tools"      tab:@"Gadgets"],
        [ACItem name:@"Teleport Grenade" id:@"teleport_grenade" cat:@"Movement" tab:@"Gadgets"],
        [ACItem name:@"Trampoline"    id:@"trampoline"     cat:@"Movement"   tab:@"Gadgets"],
        [ACItem name:@"Clover Umbrella" id:@"clover_umbrella" cat:@"Movement" tab:@"Gadgets"],
        [ACItem name:@"Umbrella"      id:@"umbrella"       cat:@"Movement"   tab:@"Gadgets"],
        [ACItem name:@"Zipline Gun"   id:@"zipline_gun"    cat:@"Movement"   tab:@"Gadgets"],
        // NATURAL
        [ACItem name:@"Stick"         id:@"stick"          cat:@"Plants"     tab:@"Natural"],
        [ACItem name:@"Rock"          id:@"rock"           cat:@"Misc"       tab:@"Natural"],
        [ACItem name:@"Ore"           id:@"ore"            cat:@"Ores"       tab:@"Natural"],
        [ACItem name:@"Gold Ore"      id:@"gold_ore"       cat:@"Ores"       tab:@"Natural"],
        [ACItem name:@"Emerald Ore"   id:@"emerald_ore"    cat:@"Ores"       tab:@"Natural"],
        [ACItem name:@"Diamond Ore"   id:@"diamond_ore"    cat:@"Ores"       tab:@"Natural"],
        [ACItem name:@"Coal"          id:@"coal"           cat:@"Ores"       tab:@"Natural"],
        [ACItem name:@"Feather"       id:@"feather"        cat:@"Misc"       tab:@"Natural"],
        [ACItem name:@"Egg"           id:@"egg"            cat:@"Misc"       tab:@"Natural"],
        [ACItem name:@"Chicken Egg"   id:@"chicken_egg"    cat:@"Misc"       tab:@"Natural"],
        [ACItem name:@"Snowball"      id:@"snowball"       cat:@"Misc"       tab:@"Natural"],
        // FOOD
        [ACItem name:@"Apple"         id:@"apple"          cat:@"Snacks"     tab:@"Food"],
        [ACItem name:@"Banana"        id:@"banana"         cat:@"Snacks"     tab:@"Food"],
        [ACItem name:@"Broccoli"      id:@"broccoli"       cat:@"Snacks"     tab:@"Food"],
        [ACItem name:@"Mega Broccoli" id:@"mega_broccoli"  cat:@"Special"    tab:@"Food"],
        [ACItem name:@"Pizza"         id:@"pizza"          cat:@"Snacks"     tab:@"Food"],
        [ACItem name:@"Pineapple"     id:@"pineapple"      cat:@"Snacks"     tab:@"Food"],
        [ACItem name:@"Coffee Cup"    id:@"coffee_cup"     cat:@"Drinks"     tab:@"Food"],
        [ACItem name:@"Presents"      id:@"presents"       cat:@"Special"    tab:@"Food"],
    ];
}

// ─── BMv1 Button ─────────────────────────────────────────────────────────────
- (void)buildBMButton {
    CGFloat size = 68;
    CGRect screen = [UIScreen mainScreen].bounds;

    _bmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _bmButton.frame = CGRectMake(screen.size.width - size - 20,
                                  screen.size.height - size - 50,
                                  size, size);
    _bmButton.layer.cornerRadius = size / 2;
    _bmButton.clipsToBounds = YES;
    _bmButton.backgroundColor = [UIColor colorWithRed:0.05 green:0.12 blue:0.23 alpha:1];
    _bmButton.layer.borderColor = CYAN_DIM.CGColor;
    _bmButton.layer.borderWidth = 2;

    // Concentric rings
    NSArray *ringRadii = @[@(size * 0.38), @(size * 0.62)];
    for (NSNumber *rNum in ringRadii) {
        CGFloat r = rNum.floatValue;
        CAShapeLayer *ring = [CAShapeLayer layer];
        ring.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size/2, size/2)
                                                   radius:r/2 startAngle:0
                                               endAngle:M_PI*2 clockwise:YES].CGPath;
        ring.fillColor = [UIColor clearColor].CGColor;
        ring.strokeColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.2].CGColor;
        ring.lineWidth = 1;
        [_bmButton.layer addSublayer:ring];
    }

    // Crosshairs
    CALayer *hLine = [CALayer layer];
    hLine.frame = CGRectMake(0, size/2 - 0.5, size, 1);
    hLine.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.15].CGColor;
    [_bmButton.layer addSublayer:hLine];

    CALayer *vLine = [CALayer layer];
    vLine.frame = CGRectMake(size/2 - 0.5, 0, 1, size);
    vLine.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.15].CGColor;
    [_bmButton.layer addSublayer:vLine];

    // Radar sweep (conic gradient via gradient layer rotated)
    CAGradientLayer *sweep = [CAGradientLayer layer];
    sweep.type = kCAGradientLayerConic;
    sweep.frame = CGRectMake(0, 0, size, size);
    sweep.startPoint = CGPointMake(0.5, 0.5);
    sweep.endPoint = CGPointMake(0.5, 0);
    sweep.colors = @[
        (id)[UIColor colorWithRed:0 green:0.75 blue:1 alpha:0].CGColor,
        (id)[UIColor colorWithRed:0 green:0.75 blue:1 alpha:0.5].CGColor,
        (id)[UIColor colorWithRed:0 green:0.75 blue:1 alpha:0].CGColor,
    ];
    sweep.locations = @[@0.0, @0.12, @0.3];

    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,size,size)].CGPath;
    sweep.mask = mask;
    _sweepLayer = sweep;
    [_bmButton.layer addSublayer:sweep];

    // Rotate animation
    CABasicAnimation *rot = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rot.fromValue = @0;
    rot.toValue = @(M_PI * 2);
    rot.duration = 4.5;
    rot.repeatCount = HUGE_VALF;
    rot.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [sweep addAnimation:rot forKey:@"radarSweep"];

    // Pulse ring
    CALayer *pulse = [CALayer layer];
    pulse.frame = CGRectMake(-4, -4, size+8, size+8);
    pulse.cornerRadius = (size+8)/2;
    pulse.borderColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.5].CGColor;
    pulse.borderWidth = 2;
    [_bmButton.layer addSublayer:pulse];

    CABasicAnimation *pulseAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnim.fromValue = @1.0;
    pulseAnim.toValue = @1.4;
    pulseAnim.duration = 4.5;
    pulseAnim.repeatCount = HUGE_VALF;
    pulseAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    CABasicAnimation *pulseOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulseOpacity.fromValue = @0.5;
    pulseOpacity.toValue = @0;
    pulseOpacity.duration = 4.5;
    pulseOpacity.repeatCount = HUGE_VALF;
    [pulse addAnimation:pulseAnim forKey:@"pulseScale"];
    [pulse addAnimation:pulseOpacity forKey:@"pulseOpacity"];

    // Label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    label.text = @"BM\nv1";
    label.numberOfLines = 2;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont fontWithName:@"Courier New" size:11] ?: [UIFont boldSystemFontOfSize:11];
    label.textColor = CYAN_COLOR;
    label.userInteractionEnabled = NO;
    [_bmButton addSubview:label];

    // Blips
    _blipLayers = [NSMutableArray array];
    [self scheduleBlips];

    // Gestures
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBMPan:)];
    [_bmButton addGestureRecognizer:pan];
    [_bmButton addTarget:self action:@selector(bmTapped) forControlEvents:UIControlEventTouchUpInside];

    [_overlayWindow.rootViewController.view addSubview:_bmButton];
}

- (void)scheduleBlips {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self spawnRandomBlips];
        [self scheduleBlips];
    });
}

- (void)spawnRandomBlips {
    CGFloat size = 68;
    CGFloat radius = size / 2 - 8;
    NSInteger count = 5 + arc4random_uniform(4);

    for (NSInteger i = 0; i < count; i++) {
        CGFloat angle = ((CGFloat)arc4random_uniform(360)) * M_PI / 180.0;
        CGFloat dist  = 6 + ((CGFloat)arc4random_uniform((uint32_t)(radius - 6)));
        CGFloat x = size/2 + dist * sinf(angle);
        CGFloat y = size/2 - dist * cosf(angle);

        CALayer *blip = [CALayer layer];
        blip.frame = CGRectMake(x - 2, y - 2, 4, 4);
        blip.cornerRadius = 2;
        blip.backgroundColor = CYAN_COLOR.CGColor;
        blip.shadowColor = CYAN_COLOR.CGColor;
        blip.shadowRadius = 3;
        blip.shadowOpacity = 1;
        blip.shadowOffset = CGSizeZero;
        blip.opacity = 0;
        [_bmButton.layer addSublayer:blip];

        // Delay based on angle (sync with sweep)
        CFTimeInterval delay = (angle / (M_PI * 2)) * 4.5;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
            fade.values = @[@0, @1, @0.7, @0.3, @0];
            fade.keyTimes = @[@0, @0.05, @0.2, @0.6, @1.0];
            fade.duration = 4.5 - delay;
            fade.fillMode = kCAFillModeForwards;
            fade.removedOnCompletion = NO;
            [blip addAnimation:fade forKey:@"blipFade"];
            blip.opacity = 0;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((4.5 - delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [blip removeFromSuperlayer];
            });
        });

        [_blipLayers addObject:blip];
    }
}

- (void)handleBMPan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    if (pan.state == UIGestureRecognizerStateBegan) {
        _dragOffset = [pan locationInView:view];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint loc = [pan locationInView:_overlayWindow.rootViewController.view];
        CGRect screen = _overlayWindow.rootViewController.view.bounds;
        CGFloat x = MIN(MAX(loc.x - _dragOffset.x, 0), screen.size.width - view.frame.size.width);
        CGFloat y = MIN(MAX(loc.y - _dragOffset.y, 0), screen.size.height - view.frame.size.height);
        view.frame = CGRectMake(x, y, view.frame.size.width, view.frame.size.height);
    }
}

- (void)bmTapped {
    [self openMenu];
}

// ─── Menu Panel ───────────────────────────────────────────────────────────────
- (void)buildMenuPanel {
    CGRect screen = [UIScreen mainScreen].bounds;
    BOOL isSmall = screen.size.width <= 428;

    CGFloat w = isSmall ? screen.size.width : MIN(420, screen.size.width * 0.92);
    CGFloat h = isSmall ? screen.size.height * 0.88 : screen.size.height * 0.82;
    CGFloat x = isSmall ? 0 : (screen.size.width - w) / 2;
    CGFloat y = isSmall ? screen.size.height : (screen.size.height - h) / 2;

    _menuPanel = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, h)];
    _menuPanel.backgroundColor = BG_COLOR;
    _menuPanel.layer.cornerRadius = isSmall ? 20 : 16;
    if (isSmall) {
        _menuPanel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    _menuPanel.layer.borderColor = BORDER_COLOR.CGColor;
    _menuPanel.layer.borderWidth = 1;
    _menuPanel.clipsToBounds = YES;

    CGFloat yOff = 0;

    // Drag handle (mobile)
    if (isSmall) {
        UIView *handle = [[UIView alloc] initWithFrame:CGRectMake(w/2 - 20, 10, 40, 4)];
        handle.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.25];
        handle.layer.cornerRadius = 2;
        [_menuPanel addSubview:handle];
        yOff = 24;
    }

    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, yOff, w, 50)];
    header.backgroundColor = SURFACE_COLOR;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 80, 50)];
    title.text = @"Bluee Mods";
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textColor = CYAN_COLOR;
    [header addSubview:title];

    // Connection badge
    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(w - 130, 12, 80, 26)];
    badge.backgroundColor = SURFACE2_COLOR;
    badge.layer.cornerRadius = 13;
    badge.layer.borderColor = BORDER_COLOR.CGColor;
    badge.layer.borderWidth = 1;

    _connDot = [[UIView alloc] initWithFrame:CGRectMake(10, 10, 6, 6)];
    _connDot.backgroundColor = [UIColor colorWithRed:1 green:0.25 blue:0.38 alpha:1];
    _connDot.layer.cornerRadius = 3;
    [badge addSubview:_connDot];

    _connLabel = [[UILabel alloc] initWithFrame:CGRectMake(22, 0, 54, 26)];
    _connLabel.text = @"OFFLINE";
    _connLabel.font = [UIFont fontWithName:@"Courier New" size:9] ?: [UIFont systemFontOfSize:9];
    _connLabel.textColor = CYAN_DIM;
    [badge addSubview:_connLabel];
    [header addSubview:badge];

    // X close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w - 44, 8, 34, 34);
    closeBtn.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.08];
    closeBtn.layer.cornerRadius = 17;
    closeBtn.layer.borderColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.3].CGColor;
    closeBtn.layer.borderWidth = 1;
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];

    // Bottom border
    UIView *hBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 49, w, 1)];
    hBorder.backgroundColor = BORDER_COLOR;
    [header addSubview:hBorder];
    [_menuPanel addSubview:header];
    yOff += 50;

    // Tabs
    _tabScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, yOff, w, 44)];
    _tabScrollView.showsHorizontalScrollIndicator = NO;
    _tabScrollView.backgroundColor = SURFACE_COLOR;
    [self buildTabsInScrollView:_tabScrollView];
    UIView *tabBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 43, w, 1)];
    tabBorder.backgroundColor = BORDER_COLOR;
    [_tabScrollView addSubview:tabBorder];
    [_menuPanel addSubview:_tabScrollView];
    yOff += 44;

    // Search
    UIView *searchBar = [[UIView alloc] initWithFrame:CGRectMake(0, yOff, w, 44)];
    searchBar.backgroundColor = SURFACE_COLOR;
    _searchField = [[UITextField alloc] initWithFrame:CGRectMake(12, 8, w - 24, 28)];
    _searchField.backgroundColor = SURFACE2_COLOR;
    _searchField.layer.cornerRadius = 8;
    _searchField.layer.borderColor = BORDER_COLOR.CGColor;
    _searchField.layer.borderWidth = 1;
    _searchField.placeholder = @"Search items...";
    _searchField.font = [UIFont fontWithName:@"Courier New" size:12] ?: [UIFont systemFontOfSize:12];
    _searchField.textColor = TEXT_COLOR;
    _searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Search items..." attributes:@{NSForegroundColorAttributeName: TEXT_DIM_COLOR}];
    UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,28)];
    _searchField.leftView = leftPad;
    _searchField.leftViewMode = UITextFieldViewModeAlways;
    [_searchField addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [searchBar addSubview:_searchField];
    UIView *sBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 43, w, 1)];
    sBorder.backgroundColor = BORDER_COLOR;
    [searchBar addSubview:sBorder];
    [_menuPanel addSubview:searchBar];
    yOff += 44;

    // Category bar
    _catScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, yOff, w, 40)];
    _catScrollView.showsHorizontalScrollIndicator = NO;
    _catScrollView.backgroundColor = SURFACE_COLOR;
    UIView *cBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 39, w, 1)];
    cBorder.backgroundColor = BORDER_COLOR;
    [_catScrollView addSubview:cBorder];
    [_menuPanel addSubview:_catScrollView];
    yOff += 40;

    // Bottom bar height
    CGFloat bottomBarH = 56;
    CGFloat listH = h - yOff - bottomBarH;

    // Collection view
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat cardW = (w - 36) / 2;
    layout.itemSize = CGSizeMake(cardW, 62);
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10, 12, 10, 12);

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, yOff, w, listH) collectionViewLayout:layout];
    _collectionView.backgroundColor = BG_COLOR;
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView registerClass:[ItemCardCell class] forCellWithReuseIdentifier:@"cell"];
    [_menuPanel addSubview:_collectionView];
    yOff += listH;

    // Qty bar
    UIView *qtyBar = [[UIView alloc] initWithFrame:CGRectMake(0, yOff, w, bottomBarH)];
    qtyBar.backgroundColor = SURFACE_COLOR;
    UIView *qBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 1)];
    qBorder.backgroundColor = BORDER_COLOR;
    [qtyBar addSubview:qBorder];

    UILabel *qtyLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 40, bottomBarH)];
    qtyLbl.text = @"QTY";
    qtyLbl.font = [UIFont fontWithName:@"Courier New" size:11] ?: [UIFont systemFontOfSize:11];
    qtyLbl.textColor = TEXT_DIM_COLOR;
    [qtyBar addSubview:qtyLbl];

    UIView *qtyControls = [[UIView alloc] initWithFrame:CGRectMake(60, 10, 140, 36)];
    qtyControls.backgroundColor = SURFACE2_COLOR;
    qtyControls.layer.cornerRadius = 10;
    qtyControls.layer.borderColor = BORDER_COLOR.CGColor;
    qtyControls.layer.borderWidth = 1;

    UIButton *minus = [UIButton buttonWithType:UIButtonTypeSystem];
    minus.frame = CGRectMake(0, 0, 40, 36);
    [minus setTitle:@"-" forState:UIControlStateNormal];
    [minus setTitleColor:CYAN_COLOR forState:UIControlStateNormal];
    minus.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [minus addTarget:self action:@selector(qtyMinus) forControlEvents:UIControlEventTouchUpInside];
    [qtyControls addSubview:minus];

    _qtyField = [[UITextField alloc] initWithFrame:CGRectMake(40, 4, 60, 28)];
    _qtyField.text = @"1";
    _qtyField.textAlignment = NSTextAlignmentCenter;
    _qtyField.font = [UIFont fontWithName:@"Courier New" size:17] ?: [UIFont boldSystemFontOfSize:17];
    _qtyField.textColor = CYAN_COLOR;
    _qtyField.backgroundColor = [UIColor clearColor];
    _qtyField.keyboardType = UIKeyboardTypeNumberPad;
    _qtyField.borderStyle = UITextBorderStyleNone;
    [_qtyField addTarget:self action:@selector(qtyChanged) forControlEvents:UIControlEventEditingChanged];
    [qtyControls addSubview:_qtyField];

    UIButton *plus = [UIButton buttonWithType:UIButtonTypeSystem];
    plus.frame = CGRectMake(100, 0, 40, 36);
    [plus setTitle:@"+" forState:UIControlStateNormal];
    [plus setTitleColor:CYAN_COLOR forState:UIControlStateNormal];
    plus.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [plus addTarget:self action:@selector(qtyPlus) forControlEvents:UIControlEventTouchUpInside];
    [qtyControls addSubview:plus];

    [qtyBar addSubview:qtyControls];
    [_menuPanel addSubview:qtyBar];

    [_overlayWindow.rootViewController.view addSubview:_menuPanel];
    _menuPanel.hidden = YES;
    [self buildCatBar];
}

- (void)buildTabsInScrollView:(UIScrollView *)sv {
    NSArray *tabs = @[@"Weapons", @"Gadgets", @"Natural", @"Food"];
    CGFloat x = 12;
    for (NSString *tab in tabs) {
        BOOL active = [tab isEqualToString:_activeTab];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat w = tab.length * 9 + 24;
        btn.frame = CGRectMake(x, 6, w, 32);
        [btn setTitle:tab forState:UIControlStateNormal];
        [btn setTitleColor:active ? CYAN_COLOR : TEXT_DIM_COLOR forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        btn.backgroundColor = active ? CYAN_GLOW : [UIColor clearColor];
        btn.layer.cornerRadius = 8;
        if (active) {
            btn.layer.borderColor = CYAN_DIM.CGColor;
            btn.layer.borderWidth = 1;
        }
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [sv addSubview:btn];
        x += w + 8;
    }
    sv.contentSize = CGSizeMake(x + 12, 44);
}

- (void)buildCatBar {
    for (UIView *v in _catScrollView.subviews) {
        if (![v isKindOfClass:[UIView class]] || v.frame.size.height == 1) continue;
        [v removeFromSuperview];
    }

    NSMutableArray *cats = [@[@"All"] mutableCopy];
    for (ACItem *item in _allItems) {
        if ([item.tab isEqualToString:_activeTab] && ![cats containsObject:item.category]) {
            [cats addObject:item.category];
        }
    }

    CGFloat x = 10;
    for (NSString *cat in cats) {
        BOOL active = [cat isEqualToString:_activeCat];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat w = cat.length * 8 + 20;
        btn.frame = CGRectMake(x, 6, w, 28);
        [btn setTitle:cat forState:UIControlStateNormal];
        [btn setTitleColor:active ? CYAN_COLOR : TEXT_DIM_COLOR forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:12];
        btn.backgroundColor = active ? CYAN_GLOW : [UIColor clearColor];
        btn.layer.cornerRadius = 14;
        btn.layer.borderColor = active ? CYAN_DIM.CGColor : BORDER_COLOR.CGColor;
        btn.layer.borderWidth = 1;
        [btn addTarget:self action:@selector(catTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_catScrollView addSubview:btn];
        x += w + 8;
    }
    _catScrollView.contentSize = CGSizeMake(x + 10, 40);
}

// ─── Open / Close ─────────────────────────────────────────────────────────────
- (void)openMenu {
    _bmButton.hidden = YES;
    _menuPanel.hidden = NO;
    CGRect screen = [UIScreen mainScreen].bounds;
    BOOL isSmall = screen.size.width <= 428;

    if (isSmall) {
        CGFloat h = _menuPanel.frame.size.height;
        _menuPanel.frame = CGRectMake(0, screen.size.height, screen.size.width, h);
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:0 animations:^{
            self->_menuPanel.frame = CGRectMake(0, screen.size.height - h, screen.size.width, h);
        } completion:nil];
    } else {
        _menuPanel.transform = CGAffineTransformMakeScale(0.92, 0.92);
        _menuPanel.alpha = 0;
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:0 animations:^{
            self->_menuPanel.transform = CGAffineTransformIdentity;
            self->_menuPanel.alpha = 1;
        } completion:nil];
    }
}

- (void)closeMenu {
    CGRect screen = [UIScreen mainScreen].bounds;
    BOOL isSmall = screen.size.width <= 428;

    if (isSmall) {
        [UIView animateWithDuration:0.3 animations:^{
            CGRect f = self->_menuPanel.frame;
            self->_menuPanel.frame = CGRectMake(f.origin.x, screen.size.height, f.size.width, f.size.height);
        } completion:^(BOOL done) {
            self->_menuPanel.hidden = YES;
            self->_bmButton.hidden = NO;
        }];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            self->_menuPanel.alpha = 0;
            self->_menuPanel.transform = CGAffineTransformMakeScale(0.92, 0.92);
        } completion:^(BOOL done) {
            self->_menuPanel.hidden = YES;
            self->_menuPanel.transform = CGAffineTransformIdentity;
            self->_menuPanel.alpha = 1;
            self->_bmButton.hidden = NO;
        }];
    }
}

// ─── Tab / Cat / Search ───────────────────────────────────────────────────────
- (void)tabTapped:(UIButton *)btn {
    _activeTab = btn.currentTitle;
    _activeCat = @"All";
    for (UIView *v in _tabScrollView.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *b = (UIButton *)v;
            BOOL active = [b.currentTitle isEqualToString:_activeTab];
            [b setTitleColor:active ? CYAN_COLOR : TEXT_DIM_COLOR forState:UIControlStateNormal];
            b.backgroundColor = active ? CYAN_GLOW : [UIColor clearColor];
            b.layer.borderWidth = active ? 1 : 0;
        }
    }
    [self buildCatBar];
    [self filterItems];
}

- (void)catTapped:(UIButton *)btn {
    _activeCat = btn.currentTitle;
    for (UIView *v in _catScrollView.subviews) {
        if ([v isKindOfClass:[UIButton class]]) {
            UIButton *b = (UIButton *)v;
            BOOL active = [b.currentTitle isEqualToString:_activeCat];
            [b setTitleColor:active ? CYAN_COLOR : TEXT_DIM_COLOR forState:UIControlStateNormal];
            b.backgroundColor = active ? CYAN_GLOW : [UIColor clearColor];
            b.layer.borderColor = active ? CYAN_DIM.CGColor : BORDER_COLOR.CGColor;
        }
    }
    [self filterItems];
}

- (void)searchChanged {
    [self filterItems];
}

- (void)filterItems {
    NSString *query = _searchField.text.lowercaseString ?: @"";
    NSMutableArray *result = [NSMutableArray array];
    for (ACItem *item in _allItems) {
        if (![item.tab isEqualToString:_activeTab]) continue;
        if (![_activeCat isEqualToString:@"All"] && ![item.category isEqualToString:_activeCat]) continue;
        if (query.length > 0) {
            NSString *itemIdFull = [NSString stringWithFormat:@"item_%@", item.itemId];
            if (![item.name.lowercaseString containsString:query] && ![itemIdFull containsString:query]) continue;
        }
        [result addObject:item];
    }
    _filteredItems = result;
    [_collectionView reloadData];
}

// ─── Qty ──────────────────────────────────────────────────────────────────────
- (void)qtyMinus {
    _qty = MAX(1, _qty - 1);
    _qtyField.text = [@(_qty) stringValue];
}

- (void)qtyPlus {
    _qty = MIN(99, _qty + 1);
    _qtyField.text = [@(_qty) stringValue];
}

- (void)qtyChanged {
    NSInteger v = [_qtyField.text integerValue];
    if (v >= 1) _qty = MIN(99, v);
}

// ─── Collection View ──────────────────────────────────────────────────────────
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return _filteredItems.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    ItemCardCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    ACItem *item = _filteredItems[indexPath.item];
    cell.nameLabel.text = item.name;
    cell.idLabel.text = [NSString stringWithFormat:@"item_%@", item.itemId];
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    ACItem *item = _filteredItems[indexPath.item];
    ItemCardCell *cell = (ItemCardCell *)[cv cellForItemAtIndexPath:indexPath];
    [cell flashSpawn];
    [self spawnItem:item];
}

// ─── Spawn / WebSocket ────────────────────────────────────────────────────────
- (void)spawnItem:(ACItem *)item {
    if (!_wsTask || _wsTask.state != NSURLSessionTaskStateRunning) {
        [self showToast:[NSString stringWithFormat:@"Not connected"] error:YES];
        return;
    }
    NSDictionary *msg = @{@"type": @"spawn", @"item": item.itemId, @"qty": @(_qty)};
    NSData *data = [NSJSONSerialization dataWithJSONObject:msg options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [_wsTask sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:str] completionHandler:^(NSError *e){}];
    [self showToast:[NSString stringWithFormat:@"Spawning %@ x%ld", item.name, (long)_qty] error:NO];
}

- (void)autoConnect {
    NSURL *url = [NSURL URLWithString:@"ws://localhost:7777"];
    _wsSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    _wsTask = [_wsSession webSocketTaskWithURL:url];
    [_wsTask resume];
    [self receiveLoop];
    [self updateConnStatus:YES];
}

- (void)receiveLoop {
    __weak typeof(self) weakSelf = self;
    [_wsTask receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf updateConnStatus:NO]; });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [weakSelf autoConnect];
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf updateConnStatus:YES]; });
        [weakSelf receiveLoop];
    }];
}

- (void)updateConnStatus:(BOOL)online {
    _connDot.backgroundColor = online
        ? CYAN_COLOR
        : [UIColor colorWithRed:1 green:0.25 blue:0.38 alpha:1];
    _connLabel.text = online ? @"LIVE" : @"OFFLINE";
}

// ─── Toast ────────────────────────────────────────────────────────────────────
- (void)showToast:(NSString *)msg error:(BOOL)err {
    UILabel *toast = [[UILabel alloc] init];
    toast.text = msg;
    toast.font = [UIFont fontWithName:@"Courier New" size:12] ?: [UIFont systemFontOfSize:12];
    toast.textColor = err ? [UIColor colorWithRed:1 green:0.4 blue:0.5 alpha:1] : CYAN_COLOR;
    toast.backgroundColor = SURFACE2_COLOR;
    toast.layer.cornerRadius = 14;
    toast.layer.borderColor = err
        ? [UIColor colorWithRed:1 green:0.25 blue:0.38 alpha:0.5].CGColor
        : CYAN_DIM.CGColor;
    toast.layer.borderWidth = 1;
    toast.clipsToBounds = YES;
    toast.textAlignment = NSTextAlignmentCenter;

    [toast sizeToFit];
    CGFloat tw = toast.frame.size.width + 32;
    CGFloat th = 36;
    CGRect screen = [UIScreen mainScreen].bounds;
    toast.frame = CGRectMake((screen.size.width - tw)/2, screen.size.height - 100, tw, th);
    toast.alpha = 0;
    toast.transform = CGAffineTransformMakeTranslation(0, 8);

    [_overlayWindow.rootViewController.view addSubview:toast];

    [UIView animateWithDuration:0.2 animations:^{
        toast.alpha = 1;
        toast.transform = CGAffineTransformIdentity;
    } completion:^(BOOL done) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 0; } completion:^(BOOL d){ [toast removeFromSuperview]; }];
        });
    }];
}

@end
