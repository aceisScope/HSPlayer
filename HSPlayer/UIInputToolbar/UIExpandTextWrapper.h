//
//  UIExpandTextWrapper.h
//  HSPlayer
//
//  Created by bhliu on 13-8-21.
//  Copyright (c) 2013年 Doubleint. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UIInputToolbar.h"

@interface UIExpandTextWrapper : NSObject<UIInputToolbarDelegate> {
    UIInputToolbar *_inputToolbar;
    UIViewController *_superViewController;
@private
    BOOL keyboardIsVisible;
}

@property (nonatomic, strong) UIInputToolbar *inputToolbar;
@property (nonatomic, strong) UIViewController *superViewController;

- (id)initWithSuperViewController:(UIViewController*)viewController;
- (void)showTextBar;
- (void)hideTextBar;

@end
