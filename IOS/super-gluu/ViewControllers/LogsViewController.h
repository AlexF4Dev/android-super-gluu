//
//  LogsViewController.h
//  oxPush2-IOS
//
//  Created by Nazar Yavornytskyy on 2/12/16.
//  Copyright © 2016 Nazar Yavornytskyy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LogsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>{

    NSMutableArray* logsArray;
    IBOutlet UIView* topView;
    IBOutlet UIImageView* topIconView;
    IBOutlet UITableView* logsTableView;
    IBOutlet UIButton* cleanLogs;
    IBOutlet UILabel* noLogsLabel;
    IBOutlet UIView* contentView;
}

@end
