#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

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
@interface BMItemCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *idLabel;
@end

@implementation BMItemCell
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
        [self.contentView addSubview:_nameLabel];

        _idLabel = [[UILabel alloc] init];
        _idLabel.font = [UIFont fontWithName:@"Courier New" size:9] ?: [UIFont systemFontOfSize:9];
        _idLabel.textColor = CYAN_DIM;
        _idLabel.numberOfLines = 1;
        _idLabel.adjustsFontSizeToFitWidth = YES;
        _idLabel.translatesAutoresizingMaskIntoConstraints = NO;
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

// ─── Main Manager ─────────────────────────────────────────────────────────────
@interface BlueeModsManager : NSObject <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIButton *bmButton;
@property (nonatomic, strong) UIView *menuPanel;
@property (nonatomic, assign) BOOL menuVisible;

@property (nonatomic, strong) NSArray *allItems;
@property (nonatomic, strong) NSArray *filteredItems;
@property (nonatomic, strong) NSString *activeTab;
@property (nonatomic, strong) NSString *activeCat;
@property (nonatomic, assign) NSInteger qty;

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UITextField *qtyField;
@property (nonatomic, strong) UIScrollView *tabScrollView;
@property (nonatomic, strong) UIScrollView *catScrollView;
@property (nonatomic, strong) UIView *connDot;
@property (nonatomic, strong) UILabel *connLabel;
@property (nonatomic, assign) CGPoint dragOffset;

@property (nonatomic, strong) NSURLSessionWebSocketTask *wsTask;
@property (nonatomic, strong) NSURLSession *wsSession;

+ (instancetype)shared;
- (void)setup;
@end

@implementation BlueeModsManager

+ (instancetype)shared {
    static BlueeModsManager *instance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ instance = [BlueeModsManager new]; });
    return instance;
}

- (void)setup {
    self.activeTab = @"Weapons";
    self.activeCat = @"All";
    self.qty = 1;
    [self buildItems];

    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s; break;
        }
    }
    _overlayWindow = scene ? [[UIWindow alloc] initWithWindowScene:scene] : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _overlayWindow.windowLevel = UIWindowLevelAlert + 100;
    _overlayWindow.backgroundColor = [UIColor clearColor];
    _overlayWindow.hidden = NO;
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor clearColor];
    _overlayWindow.rootViewController = vc;

    [self buildButton];
    [self buildMenu];
    [self filterItems];
    [self connect];
}

- (void)buildItems {
    NSMutableArray *items = [NSMutableArray array];
    // Weapons - Melee
    NSDictionary *weaponsMelee[] = {
        @{@"name":@"Arm Bone",@"id":@"arm_bone",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Baseball Bat",@"id":@"baseball_bat",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Baton",@"id":@"baton",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Bone",@"id":@"bone",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Boomspear",@"id":@"boomspear",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Crowbar",@"id":@"crowbar",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Cube Pickaxe",@"id":@"cube_pickaxe",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Drill",@"id":@"drill",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Frying Pan",@"id":@"frying_pan",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Golden Pickaxe",@"id":@"golden_pickaxe",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Great Sword",@"id":@"great_sword",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Hatchet",@"id":@"hatchet",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Lance",@"id":@"lance",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Pickaxe",@"id":@"pickaxe",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Spear",@"id":@"spear",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Sword",@"id":@"sword",@"cat":@"Melee",@"tab":@"Weapons"},
        @{@"name":@"Stellar Swords",@"id":@"stellar_swords",@"cat":@"Melee",@"tab":@"Weapons"},
    };
    for (int i = 0; i < 17; i++) [items addObject:weaponsMelee[i]];

    // Weapons - Ranged
    NSDictionary *weaponsRanged[] = {
        @{@"name":@"Boomerang",@"id":@"boomerang",@"cat":@"Ranged",@"tab":@"Weapons"},
        @{@"name":@"Crossbow",@"id":@"crossbow",@"cat":@"Ranged",@"tab":@"Weapons"},
        @{@"name":@"Dragon Pistol",@"id":@"dragon_pistol",@"cat":@"Ranged",@"tab":@"Weapons"},
        @{@"name":@"Flamethrower",@"id":@"flamethrower",@"cat":@"Ranged",@"tab":@"Weapons"},
        @{@"name":@"Golden Gun",@"id":@"golden_gun",@"cat":@"Ranged",@"tab":@"Weapons"},
        @{@"name":@"Revolver",@"id":@"revolver",@"cat":@"Ranged",@"tab":@"Weapons"},
        @{@"name":@"Shotgun",@"id":@"shotgun",@"cat":@"Ranged",@"tab":@"Weapons"},
    };
    for (int i = 0; i < 7; i++) [items addObject:weaponsRanged[i]];

    // Weapons - Explosives
    NSDictionary *explosives[] = {
        @{@"name":@"Dragon Rocket",@"id":@"dragon_rocket_launcher",@"cat":@"Explosives",@"tab":@"Weapons"},
        @{@"name":@"Easter RPG",@"id":@"easter_rpg",@"cat":@"Explosives",@"tab":@"Weapons"},
        @{@"name":@"Dynamite",@"id":@"dynamite",@"cat":@"Explosives",@"tab":@"Weapons"},
        @{@"name":@"Flashbang",@"id":@"flashbang",@"cat":@"Explosives",@"tab":@"Weapons"},
        @{@"name":@"Bone Shield",@"id":@"bone_shield",@"cat":@"Shields",@"tab":@"Weapons"},
    };
    for (int i = 0; i < 5; i++) [items addObject:explosives[i]];

    // Gadgets
    NSDictionary *gadgets[] = {
        @{@"name":@"Balloon",@"id":@"balloon",@"cat":@"Fun",@"tab":@"Gadgets"},
        @{@"name":@"Camera",@"id":@"camera",@"cat":@"Tools",@"tab":@"Gadgets"},
        @{@"name":@"Flashlight",@"id":@"flashlight",@"cat":@"Tools",@"tab":@"Gadgets"},
        @{@"name":@"Hand Jetpack",@"id":@"handheld_jetpack",@"cat":@"Movement",@"tab":@"Gadgets"},
        @{@"name":@"Hookshot",@"id":@"hookshot",@"cat":@"Movement",@"tab":@"Gadgets"},
        @{@"name":@"Hover Board",@"id":@"hoverboard",@"cat":@"Movement",@"tab":@"Gadgets"},
        @{@"name":@"Money Gun",@"id":@"money_gun",@"cat":@"Fun",@"tab":@"Gadgets"},
        @{@"name":@"Pogo Stick",@"id":@"pogo_stick",@"cat":@"Movement",@"tab":@"Gadgets"},
        @{@"name":@"Trampoline",@"id":@"trampoline",@"cat":@"Movement",@"tab":@"Gadgets"},
        @{@"name":@"Umbrella",@"id":@"umbrella",@"cat":@"Movement",@"tab":@"Gadgets"},
        @{@"name":@"Zipline Gun",@"id":@"zipline_gun",@"cat":@"Movement",@"tab":@"Gadgets"},
    };
    for (int i = 0; i < 11; i++) [items addObject:gadgets[i]];

    // Natural
    NSDictionary *natural[] = {
        @{@"name":@"Rock",@"id":@"rock",@"cat":@"Misc",@"tab":@"Natural"},
        @{@"name":@"Stick",@"id":@"stick",@"cat":@"Plants",@"tab":@"Natural"},
        @{@"name":@"Gold Ore",@"id":@"gold_ore",@"cat":@"Ores",@"tab":@"Natural"},
        @{@"name":@"Emerald Ore",@"id":@"emerald_ore",@"cat":@"Ores",@"tab":@"Natural"},
        @{@"name":@"Diamond Ore",@"id":@"diamond_ore",@"cat":@"Ores",@"tab":@"Natural"},
        @{@"name":@"Coal",@"id":@"coal",@"cat":@"Ores",@"tab":@"Natural"},
        @{@"name":@"Feather",@"id":@"feather",@"cat":@"Misc",@"tab":@"Natural"},
        @{@"name":@"Snowball",@"id":@"snowball",@"cat":@"Misc",@"tab":@"Natural"},
    };
    for (int i = 0; i < 8; i++) [items addObject:natural[i]];

    // Food
    NSDictionary *food[] = {
        @{@"name":@"Apple",@"id":@"apple",@"cat":@"Snacks",@"tab":@"Food"},
        @{@"name":@"Banana",@"id":@"banana",@"cat":@"Snacks",@"tab":@"Food"},
        @{@"name":@"Pizza",@"id":@"pizza",@"cat":@"Snacks",@"tab":@"Food"},
        @{@"name":@"Broccoli",@"id":@"broccoli",@"cat":@"Snacks",@"tab":@"Food"},
        @{@"name":@"Mega Broccoli",@"id":@"mega_broccoli",@"cat":@"Special",@"tab":@"Food"},
        @{@"name":@"Coffee Cup",@"id":@"coffee_cup",@"cat":@"Drinks",@"tab":@"Food"},
    };
    for (int i = 0; i < 6; i++) [items addObject:food[i]];

    self.allItems = items;
}

- (void)buildButton {
    CGFloat size = 68;
    CGRect screen = [UIScreen mainScreen].bounds;
    _bmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _bmButton.frame = CGRectMake(screen.size.width - size - 20, screen.size.height - size - 50, size, size);
    _bmButton.layer.cornerRadius = size / 2;
    _bmButton.clipsToBounds = YES;
    _bmButton.backgroundColor = [UIColor colorWithRed:0.05 green:0.12 blue:0.23 alpha:1];
    _bmButton.layer.borderColor = CYAN_DIM.CGColor;
    _bmButton.layer.borderWidth = 2;

    // Rings
    NSArray *radii = @[@(size * 0.38), @(size * 0.62)];
    for (NSNumber *rNum in radii) {
        CGFloat r = rNum.floatValue;
        CAShapeLayer *ring = [CAShapeLayer layer];
        ring.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(size/2, size/2) radius:r/2 startAngle:0 endAngle:M_PI*2 clockwise:YES].CGPath;
        ring.fillColor = [UIColor clearColor].CGColor;
        ring.strokeColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.2].CGColor;
        ring.lineWidth = 1;
        [_bmButton.layer addSublayer:ring];
    }

    // Crosshairs
    CALayer *h = [CALayer layer]; h.frame = CGRectMake(0, size/2-0.5, size, 1);
    h.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.15].CGColor;
    [_bmButton.layer addSublayer:h];
    CALayer *v = [CALayer layer]; v.frame = CGRectMake(size/2-0.5, 0, 1, size);
    v.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.15].CGColor;
    [_bmButton.layer addSublayer:v];

    // Sweep
    CAGradientLayer *sweep = [CAGradientLayer layer];
    sweep.type = kCAGradientLayerConic;
    sweep.frame = CGRectMake(0, 0, size, size);
    sweep.startPoint = CGPointMake(0.5, 0.5);
    sweep.endPoint = CGPointMake(0.5, 0);
    sweep.colors = @[(id)[UIColor colorWithRed:0 green:0.75 blue:1 alpha:0].CGColor, (id)[UIColor colorWithRed:0 green:0.75 blue:1 alpha:0.5].CGColor, (id)[UIColor colorWithRed:0 green:0.75 blue:1 alpha:0].CGColor];
    sweep.locations = @[@0.0, @0.12, @0.3];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0,0,size,size)].CGPath;
    sweep.mask = mask;
    CABasicAnimation *rot = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rot.fromValue = @0; rot.toValue = @(M_PI*2); rot.duration = 4.5;
    rot.repeatCount = HUGE_VALF;
    rot.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [sweep addAnimation:rot forKey:@"sweep"];
    [_bmButton.layer addSublayer:sweep];

    // Label
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0,0,size,size)];
    lbl.text = @"BM\nv1"; lbl.numberOfLines = 2; lbl.textAlignment = NSTextAlignmentCenter;
    lbl.font = [UIFont boldSystemFontOfSize:11]; lbl.textColor = CYAN_COLOR;
    lbl.userInteractionEnabled = NO;
    [_bmButton addSubview:lbl];

    // Blips
    [self scheduleBlips];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [_bmButton addGestureRecognizer:pan];
    [_bmButton addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    [_overlayWindow.rootViewController.view addSubview:_bmButton];
}

- (void)scheduleBlips {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self spawnBlips];
        [self scheduleBlips];
    });
}

- (void)spawnBlips {
    CGFloat size = 68, radius = size/2 - 8;
    NSInteger count = 5 + arc4random_uniform(4);
    for (NSInteger i = 0; i < count; i++) {
        CGFloat angle = ((CGFloat)arc4random_uniform(360)) * M_PI / 180.0;
        CGFloat dist = 6 + (CGFloat)arc4random_uniform((uint32_t)(radius-6));
        CGFloat x = size/2 + dist * sinf(angle);
        CGFloat y = size/2 - dist * cosf(angle);
        CALayer *blip = [CALayer layer];
        blip.frame = CGRectMake(x-2, y-2, 4, 4);
        blip.cornerRadius = 2;
        blip.backgroundColor = CYAN_COLOR.CGColor;
        blip.opacity = 0;
        [_bmButton.layer addSublayer:blip];
        CFTimeInterval delay = (angle/(M_PI*2)) * 4.5;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CAKeyframeAnimation *fade = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
            fade.values = @[@0,@1,@0.7,@0.3,@0];
            fade.keyTimes = @[@0,@0.05,@0.2,@0.6,@1.0];
            fade.duration = 4.5 - delay;
            fade.fillMode = kCAFillModeForwards;
            fade.removedOnCompletion = NO;
            [blip addAnimation:fade forKey:@"fade"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((4.5-delay)*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [blip removeFromSuperlayer];
            });
        });
    }
}

- (void)onPan:(UIPanGestureRecognizer *)pan {
    UIView *v = pan.view;
    if (pan.state == UIGestureRecognizerStateBegan) {
        _dragOffset = [pan locationInView:v];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint loc = [pan locationInView:_overlayWindow.rootViewController.view];
        CGRect s = _overlayWindow.rootViewController.view.bounds;
        CGFloat x = MIN(MAX(loc.x - _dragOffset.x, 0), s.size.width - v.frame.size.width);
        CGFloat y = MIN(MAX(loc.y - _dragOffset.y, 0), s.size.height - v.frame.size.height);
        v.frame = CGRectMake(x, y, v.frame.size.width, v.frame.size.height);
    }
}

- (void)onTap { [self openMenu]; }

- (void)buildMenu {
    CGRect screen = [UIScreen mainScreen].bounds;
    BOOL small = screen.size.width <= 428;
    CGFloat w = small ? screen.size.width : MIN(420, screen.size.width*0.92);
    CGFloat h = small ? screen.size.height*0.88 : screen.size.height*0.82;
    CGFloat x = small ? 0 : (screen.size.width-w)/2;
    CGFloat y = small ? screen.size.height : (screen.size.height-h)/2;

    _menuPanel = [[UIView alloc] initWithFrame:CGRectMake(x,y,w,h)];
    _menuPanel.backgroundColor = BG_COLOR;
    _menuPanel.layer.cornerRadius = small ? 20 : 16;
    if (small) _menuPanel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    _menuPanel.layer.borderColor = BORDER_COLOR.CGColor;
    _menuPanel.layer.borderWidth = 1;
    _menuPanel.clipsToBounds = YES;

    CGFloat yOff = 0;
    if (small) {
        UIView *handle = [[UIView alloc] initWithFrame:CGRectMake(w/2-20,10,40,4)];
        handle.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.25];
        handle.layer.cornerRadius = 2;
        [_menuPanel addSubview:handle];
        yOff = 24;
    }

    // Header
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,yOff,w,50)];
    header.backgroundColor = SURFACE_COLOR;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16,0,w-120,50)];
    title.text = @"Bluee Mods"; title.font = [UIFont boldSystemFontOfSize:18]; title.textColor = CYAN_COLOR;
    [header addSubview:title];

    UIView *badge = [[UIView alloc] initWithFrame:CGRectMake(w-160,12,70,26)];
    badge.backgroundColor = SURFACE2_COLOR; badge.layer.cornerRadius = 13;
    badge.layer.borderColor = BORDER_COLOR.CGColor; badge.layer.borderWidth = 1;
    _connDot = [[UIView alloc] initWithFrame:CGRectMake(10,10,6,6)];
    _connDot.backgroundColor = [UIColor colorWithRed:1 green:0.25 blue:0.38 alpha:1];
    _connDot.layer.cornerRadius = 3;
    [badge addSubview:_connDot];
    _connLabel = [[UILabel alloc] initWithFrame:CGRectMake(22,0,44,26)];
    _connLabel.text = @"OFFLINE"; _connLabel.font = [UIFont systemFontOfSize:9]; _connLabel.textColor = CYAN_DIM;
    [badge addSubview:_connLabel];
    [header addSubview:badge];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(w-44,8,34,34);
    closeBtn.backgroundColor = [UIColor colorWithRed:0 green:0.63 blue:1 alpha:0.08];
    closeBtn.layer.cornerRadius = 17;
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    UIView *hb = [[UIView alloc] initWithFrame:CGRectMake(0,49,w,1)]; hb.backgroundColor = BORDER_COLOR;
    [header addSubview:hb];
    [_menuPanel addSubview:header];
    yOff += 50;

    // Tabs
    _tabScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,yOff,w,44)];
    _tabScrollView.showsHorizontalScrollIndicator = NO; _tabScrollView.backgroundColor = SURFACE_COLOR;
    [self buildTabs]; [_menuPanel addSubview:_tabScrollView]; yOff += 44;

    // Search
    UIView *sb = [[UIView alloc] initWithFrame:CGRectMake(0,yOff,w,44)]; sb.backgroundColor = SURFACE_COLOR;
    _searchField = [[UITextField alloc] initWithFrame:CGRectMake(12,8,w-24,28)];
    _searchField.backgroundColor = SURFACE2_COLOR; _searchField.layer.cornerRadius = 8;
    _searchField.layer.borderColor = BORDER_COLOR.CGColor; _searchField.layer.borderWidth = 1;
    _searchField.font = [UIFont systemFontOfSize:12]; _searchField.textColor = TEXT_COLOR;
    _searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Search items..." attributes:@{NSForegroundColorAttributeName:TEXT_DIM_COLOR}];
    UIView *lp = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,28)]; _searchField.leftView = lp; _searchField.leftViewMode = UITextFieldViewModeAlways;
    [_searchField addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [sb addSubview:_searchField];
    UIView *sbb = [[UIView alloc] initWithFrame:CGRectMake(0,43,w,1)]; sbb.backgroundColor = BORDER_COLOR; [sb addSubview:sbb];
    [_menuPanel addSubview:sb]; yOff += 44;

    // Cat bar
    _catScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,yOff,w,40)];
    _catScrollView.showsHorizontalScrollIndicator = NO; _catScrollView.backgroundColor = SURFACE_COLOR;
    UIView *cb = [[UIView alloc] initWithFrame:CGRectMake(0,39,w,1)]; cb.backgroundColor = BORDER_COLOR;
    [_catScrollView addSubview:cb]; [_menuPanel addSubview:_catScrollView]; yOff += 40;

    CGFloat bottomH = 56, listH = h - yOff - bottomH;
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat cw = (w-36)/2; layout.itemSize = CGSizeMake(cw, 62);
    layout.minimumInteritemSpacing = 10; layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(10,12,10,12);
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0,yOff,w,listH) collectionViewLayout:layout];
    _collectionView.backgroundColor = BG_COLOR; _collectionView.delegate = self; _collectionView.dataSource = self;
    [_collectionView registerClass:[BMItemCell class] forCellWithReuseIdentifier:@"cell"];
    [_menuPanel addSubview:_collectionView]; yOff += listH;

    // Qty bar
    UIView *qb = [[UIView alloc] initWithFrame:CGRectMake(0,yOff,w,bottomH)]; qb.backgroundColor = SURFACE_COLOR;
    UIView *qbb = [[UIView alloc] initWithFrame:CGRectMake(0,0,w,1)]; qbb.backgroundColor = BORDER_COLOR; [qb addSubview:qbb];
    UILabel *ql = [[UILabel alloc] initWithFrame:CGRectMake(16,0,40,bottomH)];
    ql.text = @"QTY"; ql.font = [UIFont systemFontOfSize:11]; ql.textColor = TEXT_DIM_COLOR; [qb addSubview:ql];
    UIView *qc = [[UIView alloc] initWithFrame:CGRectMake(60,10,140,36)];
    qc.backgroundColor = SURFACE2_COLOR; qc.layer.cornerRadius = 10;
    qc.layer.borderColor = BORDER_COLOR.CGColor; qc.layer.borderWidth = 1;
    UIButton *minus = [UIButton buttonWithType:UIButtonTypeSystem];
    minus.frame = CGRectMake(0,0,40,36); [minus setTitle:@"-" forState:UIControlStateNormal];
    [minus setTitleColor:CYAN_COLOR forState:UIControlStateNormal]; minus.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [minus addTarget:self action:@selector(qtyMinus) forControlEvents:UIControlEventTouchUpInside]; [qc addSubview:minus];
    _qtyField = [[UITextField alloc] initWithFrame:CGRectMake(40,4,60,28)];
    _qtyField.text = @"1"; _qtyField.textAlignment = NSTextAlignmentCenter;
    _qtyField.font = [UIFont boldSystemFontOfSize:17]; _qtyField.textColor = CYAN_COLOR;
    _qtyField.backgroundColor = [UIColor clearColor]; _qtyField.keyboardType = UIKeyboardTypeNumberPad;
    [_qtyField addTarget:self action:@selector(qtyChanged) forControlEvents:UIControlEventEditingChanged]; [qc addSubview:_qtyField];
    UIButton *plus = [UIButton buttonWithType:UIButtonTypeSystem];
    plus.frame = CGRectMake(100,0,40,36); [plus setTitle:@"+" forState:UIControlStateNormal];
    [plus setTitleColor:CYAN_COLOR forState:UIControlStateNormal]; plus.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [plus addTarget:self action:@selector(qtyPlus) forControlEvents:UIControlEventTouchUpInside]; [qc addSubview:plus];
    [qb addSubview:qc]; [_menuPanel addSubview:qb];

    [_overlayWindow.rootViewController.view addSubview:_menuPanel];
    _menuPanel.hidden = YES;
    [self buildCatBar];
}

- (void)buildTabs {
    for (UIView *v in _tabScrollView.subviews) [v removeFromSuperview];
    NSArray *tabs = @[@"Weapons",@"Gadgets",@"Natural",@"Food"];
    CGFloat x = 12;
    for (NSString *tab in tabs) {
        BOOL active = [tab isEqualToString:_activeTab];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat bw = tab.length * 9 + 24;
        btn.frame = CGRectMake(x,6,bw,32);
        [btn setTitle:tab forState:UIControlStateNormal];
        [btn setTitleColor:active ? CYAN_COLOR : TEXT_DIM_COLOR forState:UIControlStateNormal];
        btn.backgroundColor = active ? CYAN_GLOW : [UIColor clearColor];
        btn.layer.cornerRadius = 8;
        if (active) { btn.layer.borderColor = CYAN_DIM.CGColor; btn.layer.borderWidth = 1; }
        [btn addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_tabScrollView addSubview:btn]; x += bw + 8;
    }
    _tabScrollView.contentSize = CGSizeMake(x+12, 44);
}

- (void)buildCatBar {
    for (UIView *v in _catScrollView.subviews) { if (v.frame.size.height != 1) [v removeFromSuperview]; }
    NSMutableArray *cats = [@[@"All"] mutableCopy];
    for (NSDictionary *item in _allItems) {
        if ([item[@"tab"] isEqualToString:_activeTab] && ![cats containsObject:item[@"cat"]]) [cats addObject:item[@"cat"]];
    }
    CGFloat x = 10;
    for (NSString *cat in cats) {
        BOOL active = [cat isEqualToString:_activeCat];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        CGFloat bw = cat.length * 8 + 20;
        btn.frame = CGRectMake(x,6,bw,28);
        [btn setTitle:cat forState:UIControlStateNormal];
        [btn setTitleColor:active ? CYAN_COLOR : TEXT_DIM_COLOR forState:UIControlStateNormal];
        btn.backgroundColor = active ? CYAN_GLOW : [UIColor clearColor];
        btn.layer.cornerRadius = 14;
        btn.layer.borderColor = active ? CYAN_DIM.CGColor : BORDER_COLOR.CGColor;
        btn.layer.borderWidth = 1;
        [btn addTarget:self action:@selector(catTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_catScrollView addSubview:btn]; x += bw + 8;
    }
    _catScrollView.contentSize = CGSizeMake(x+10, 40);
}

- (void)openMenu {
    _bmButton.hidden = YES; _menuPanel.hidden = NO;
    CGRect screen = [UIScreen mainScreen].bounds;
    BOOL small = screen.size.width <= 428;
    if (small) {
        CGFloat mh = _menuPanel.frame.size.height;
        _menuPanel.frame = CGRectMake(0, screen.size.height, screen.size.width, mh);
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:0 animations:^{
            self->_menuPanel.frame = CGRectMake(0, screen.size.height-mh, screen.size.width, mh);
        } completion:nil];
    } else {
        _menuPanel.transform = CGAffineTransformMakeScale(0.92, 0.92); _menuPanel.alpha = 0;
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:0 animations:^{
            self->_menuPanel.transform = CGAffineTransformIdentity; self->_menuPanel.alpha = 1;
        } completion:nil];
    }
}

- (void)closeMenu {
    CGRect screen = [UIScreen mainScreen].bounds; BOOL small = screen.size.width <= 428;
    if (small) {
        [UIView animateWithDuration:0.3 animations:^{
            CGRect f = self->_menuPanel.frame;
            self->_menuPanel.frame = CGRectMake(f.origin.x, screen.size.height, f.size.width, f.size.height);
        } completion:^(BOOL d) { self->_menuPanel.hidden = YES; self->_bmButton.hidden = NO; }];
    } else {
        [UIView animateWithDuration:0.25 animations:^{ self->_menuPanel.alpha = 0; self->_menuPanel.transform = CGAffineTransformMakeScale(0.92,0.92); }
         completion:^(BOOL d) { self->_menuPanel.hidden = YES; self->_menuPanel.transform = CGAffineTransformIdentity; self->_menuPanel.alpha = 1; self->_bmButton.hidden = NO; }];
    }
}

- (void)tabTapped:(UIButton *)btn {
    _activeTab = btn.currentTitle; _activeCat = @"All";
    [self buildTabs]; [self buildCatBar]; [self filterItems];
}

- (void)catTapped:(UIButton *)btn {
    _activeCat = btn.currentTitle; [self buildCatBar]; [self filterItems];
}

- (void)searchChanged { [self filterItems]; }

- (void)filterItems {
    NSString *q = _searchField.text.lowercaseString ?: @"";
    NSMutableArray *r = [NSMutableArray array];
    for (NSDictionary *item in _allItems) {
        if (![item[@"tab"] isEqualToString:_activeTab]) continue;
        if (![_activeCat isEqualToString:@"All"] && ![item[@"cat"] isEqualToString:_activeCat]) continue;
        if (q.length > 0) {
            NSString *full = [NSString stringWithFormat:@"item_%@", item[@"id"]];
            if (![item[@"name"] lowercaseString] && ![full containsString:q]) continue;
            if (![[item[@"name"] lowercaseString] containsString:q] && ![full containsString:q]) continue;
        }
        [r addObject:item];
    }
    _filteredItems = r; [_collectionView reloadData];
}

- (void)qtyMinus { _qty = MAX(1,_qty-1); _qtyField.text = [@(_qty) stringValue]; }
- (void)qtyPlus  { _qty = MIN(99,_qty+1); _qtyField.text = [@(_qty) stringValue]; }
- (void)qtyChanged { NSInteger v = [_qtyField.text integerValue]; if (v>=1) _qty = MIN(99,v); }

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return _filteredItems.count; }
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    BMItemCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:ip];
    NSDictionary *item = _filteredItems[ip.item];
    cell.nameLabel.text = item[@"name"];
    cell.idLabel.text = [NSString stringWithFormat:@"item_%@", item[@"id"]];
    return cell;
}
- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *item = _filteredItems[ip.item];
    BMItemCell *cell = (BMItemCell *)[cv cellForItemAtIndexPath:ip];
    [cell flashSpawn];
    [self spawn:item];
}

- (void)spawn:(NSDictionary *)item {
    if (!_wsTask || _wsTask.state != NSURLSessionTaskStateRunning) {
        [self toast:@"Not connected" error:YES]; return;
    }
    NSDictionary *msg = @{@"type":@"spawn",@"item":item[@"id"],@"qty":@(_qty)};
    NSData *data = [NSJSONSerialization dataWithJSONObject:msg options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [_wsTask sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:str] completionHandler:^(NSError *e){}];
    [self toast:[NSString stringWithFormat:@"Spawning %@ x%ld", item[@"name"], (long)_qty] error:NO];
}

- (void)connect {
    _wsSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    _wsTask = [_wsSession webSocketTaskWithURL:[NSURL URLWithString:@"ws://localhost:7777"]];
    [_wsTask resume];
    [self recv];
    dispatch_async(dispatch_get_main_queue(), ^{ [self setOnline:YES]; });
}

- (void)recv {
    __weak typeof(self) w = self;
    [_wsTask receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *err) {
        if (err) {
            dispatch_async(dispatch_get_main_queue(), ^{ [w setOnline:NO]; });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [w connect]; });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ [w setOnline:YES]; });
        [w recv];
    }];
}

- (void)setOnline:(BOOL)on {
    _connDot.backgroundColor = on ? CYAN_COLOR : [UIColor colorWithRed:1 green:0.25 blue:0.38 alpha:1];
    _connLabel.text = on ? @"LIVE" : @"OFFLINE";
}

- (void)toast:(NSString *)msg error:(BOOL)err {
    UILabel *t = [[UILabel alloc] init];
    t.text = msg; t.font = [UIFont systemFontOfSize:12];
    t.textColor = err ? [UIColor colorWithRed:1 green:0.4 blue:0.5 alpha:1] : CYAN_COLOR;
    t.backgroundColor = SURFACE2_COLOR; t.layer.cornerRadius = 14;
    t.layer.borderColor = err ? [UIColor colorWithRed:1 green:0.25 blue:0.38 alpha:0.5].CGColor : CYAN_DIM.CGColor;
    t.layer.borderWidth = 1; t.clipsToBounds = YES; t.textAlignment = NSTextAlignmentCenter;
    [t sizeToFit];
    CGFloat tw = t.frame.size.width + 32, th = 36;
    CGRect s = [UIScreen mainScreen].bounds;
    t.frame = CGRectMake((s.size.width-tw)/2, s.size.height-100, tw, th);
    t.alpha = 0; t.transform = CGAffineTransformMakeTranslation(0,8);
    [_overlayWindow.rootViewController.view addSubview:t];
    [UIView animateWithDuration:0.2 animations:^{ t.alpha=1; t.transform=CGAffineTransformIdentity; } completion:^(BOOL d){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{ t.alpha=0; } completion:^(BOOL dd){ [t removeFromSuperview]; }];
        });
    }];
}

@end

// ─── Hook ─────────────────────────────────────────────────────────────────────
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [[BlueeModsManager shared] setup];
        });
    });
}
%end
