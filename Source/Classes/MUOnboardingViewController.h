#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString *const MUInitialSetupStartedKey;
FOUNDATION_EXPORT NSString *const MUInitialSetupCompletedKey;

@interface MUOnboardingViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong, readonly) UITableView *tableView;
+ (BOOL)shouldPresentForDefaults:(NSUserDefaults *)defaults hasExistingInstallation:(BOOL)existing;
- (instancetype)initWithCompletion:(void (^)(void))completion;
@end
