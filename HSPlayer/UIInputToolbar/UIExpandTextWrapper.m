//
//  UIExpandTextWrapper.m
//  HSPlayer
//
//  Created by bhliu on 13-8-21.
//  Copyright (c) 2013年 Doubleint. All rights reserved.
//

#import "UIExpandTextWrapper.h"

#define kStatusBarHeight 20
#define kDefaultToolbarHeight 40
#define kKeyboardHeightPortrait 216
#define kKeyboardHeightLandscape 140

@implementation UIExpandTextWrapper


- (id)initWithSuperViewController:(UIViewController*)viewController
{
    self = [super init];
    if (self) {
        
        keyboardIsVisible = NO;
        self.superViewController = viewController;
        
        /* Calculate screen size */
        CGRect screenFrame = [[UIScreen mainScreen] applicationFrame];

        /* Create toolbar */
        self.inputToolbar = [[UIInputToolbar alloc] initWithFrame:CGRectMake(0, screenFrame.size.height-kDefaultToolbarHeight, screenFrame.size.width, kDefaultToolbarHeight)];
        [self.superViewController.view addSubview:self.inputToolbar];
        self.inputToolbar.inputDelegate = self;
        self.inputToolbar.textView.placeholder = @"Placeholder";
        
        /* Listen for keyboard */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}


- (void)dealloc
{
    /* No longer listen for keyboard */
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark -
#pragma mark Notifications

- (void)keyboardWillShow:(NSNotification *)notification
{
    /* Move the toolbar to above the keyboard */
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	CGRect frame = self.inputToolbar.frame;
    if (UIInterfaceOrientationIsPortrait(self.superViewController.interfaceOrientation)) {
        frame.origin.y = self.superViewController.view.frame.size.height - frame.size.height - kKeyboardHeightPortrait;
    }
    else {
        frame.origin.y = self.superViewController.view.frame.size.width - frame.size.height - kKeyboardHeightLandscape - kStatusBarHeight;
    }
	self.inputToolbar.frame = frame;
	[UIView commitAnimations];
    keyboardIsVisible = YES;
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    /* Move the toolbar back to bottom of the screen */
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	CGRect frame = self.inputToolbar.frame;
    if (UIInterfaceOrientationIsPortrait(self.superViewController.interfaceOrientation)) {
        frame.origin.y = self.superViewController.view.frame.size.height - frame.size.height;
    }
    else {
        frame.origin.y = self.superViewController.view.frame.size.width - frame.size.height;
    }
	self.inputToolbar.frame = frame;
	[UIView commitAnimations];
    keyboardIsVisible = NO;
}

-(void)inputButtonPressed:(NSString *)inputText
{
    /* Called when toolbar button is pressed */
    NSLog(@"Pressed button with text: '%@'", inputText);
}


@end
