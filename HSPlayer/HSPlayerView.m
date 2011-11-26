//
//  HSPLayerView.m
//  HSPlayer
//
//  Created by Simon Blommegård on 2011-11-26.
//  Copyright (c) 2011 Doubleint. All rights reserved.
//

#import "HSPlayerView.h"

// Contexts for KVO
static void *HSPlayerViewPlayerRateObservationContext = &HSPlayerViewPlayerRateObservationContext;
static void *HSPlayerViewPlayerCurrentItemObservationContext = &HSPlayerViewPlayerCurrentItemObservationContext;
static void *HSPlayerViewPlayerItemStatusObservationContext = &HSPlayerViewPlayerItemStatusObservationContext;
static void *HSPlayerViewPlaterItemDurationObservationContext = &HSPlayerViewPlaterItemDurationObservationContext;
static void *HSPlayerViewPlayerLayerReadyForDisplayObservationContext = &HSPlayerViewPlayerLayerReadyForDisplayObservationContext;

@interface HSPlayerView ()
/*
@property (nonatomic, strong) UIView *bottomControlsView;
@property (nonatomic, strong) UIView *topControlsView;
*/
@property (nonatomic, strong, readwrite) AVPlayer *player;
/*
 Use this to set the videoGravity, animatable
 Look in <AVFoundation/AVAnimation.h> for possible values
 Defaults to AVLayerVideoGravityResizeAspect
 */
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, assign) CMTime duration;

@property (nonatomic, strong) id playerTimeObserver;

@property (nonatomic, assign) BOOL seekToZeroBeforePlay;
@property (nonatomic, assign) BOOL readyForDisplayTriggered;


- (void)doneLoadingAsset:(AVAsset *)asset withKeys:(NSArray *)keys;
@end

@implementation HSPlayerView

@dynamic player;
@dynamic playerLayer;

@synthesize asset = _asset;
@synthesize URL = _URL;
@synthesize playerItem = _playerItem;
@dynamic duration;

@synthesize playerTimeObserver = _playerTimeObserver;

@synthesize seekToZeroBeforePlay = _seekToZeroBeforePlay;
@synthesize readyForDisplayTriggered = _readyForDisplayTriggered;


+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self.playerLayer setOpacity:0];
        [self.playerLayer addObserver:self
                           forKeyPath:@"readyForDisplay"
                              options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                              context:HSPlayerViewPlayerLayerReadyForDisplayObservationContext];
    }
    
    return self;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
	if (context == HSPlayerViewPlayerItemStatusObservationContext) {
        // Sync buttons
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerStatusUnknown: {
                // Fail
                // Sync buttons
            }
            break;
                
            case AVPlayerStatusReadyToPlay: {
                // Get duration
                // Enable GO!
                [self play:self];
            }
                break;
                
            case AVPlayerStatusFailed: {
                //Error
            }
                break;
        }
	}

	else if (context == HSPlayerViewPlayerRateObservationContext) {
        // Sync buttons
	}
    
    // -replaceCurrentItemWithPlayerItem: && new
	else if (context == HSPlayerViewPlayerCurrentItemObservationContext) {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        // Null?
        if (newPlayerItem == (id)[NSNull null]) {
            // Disable
        }
        else {
            // New title
            // Sync buttons
            [self.playerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
        }
	}
    
    else if (context == HSPlayerViewPlaterItemDurationObservationContext) {
        // Sync scrubber
    }
    
    // Animate in the player layer
    else if (context == HSPlayerViewPlayerLayerReadyForDisplayObservationContext) {
        BOOL ready = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (ready && !self.readyForDisplayTriggered) {
            [self setReadyForDisplayTriggered:YES];
            
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            [animation setFromValue:[NSNumber numberWithFloat:0.]];
            [animation setToValue:[NSNumber numberWithFloat:1.]];
            [animation setDuration:1.];
            [self.playerLayer addAnimation:animation forKey:nil];
            [self.playerLayer setOpacity:1.];
        }
    }
    
	else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Properties

- (AVPlayer *)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *) [self layer] setPlayer:player];
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)[self layer];
}

- (void)setURL:(NSURL *)URL {
    [self willChangeValueForKey:@"URL"];
    _URL = URL;
    [self didChangeValueForKey:@"URL"];
    
    // Create Asset, and load
    
    [self setAsset:[AVURLAsset URLAssetWithURL:URL options:nil]];
    NSArray *keys = [NSArray arrayWithObjects:@"tracks", @"playable", nil];
    
    [self.asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
       dispatch_async(dispatch_get_main_queue(), ^{
           
           // Displatch to main queue!
           [self doneLoadingAsset:self.asset withKeys:keys];
       });
    }];
}

- (CMTime)duration {
    if ([self.playerItem respondsToSelector:@selector(duration)] && self.player.currentItem.status == AVPlayerItemStatusReadyToPlay)
        return self.playerItem.duration;
    else
        return kCMTimeInvalid;
}

#pragma mark - 

- (void)play:(id)sender {
	if (self.seekToZeroBeforePlay)  {
		[self setSeekToZeroBeforePlay:NO];
		[self.player seekToTime:kCMTimeZero];
	}
    
    [self.player play];
	
    // Update buttons
}

- (void)pause:(id)sender {
    [self.player pause];
    
    // Update buttons
}

#pragma mark - Private

- (void)doneLoadingAsset:(AVAsset *)asset withKeys:(NSArray *)keys {
    
    // Check if all keys is OK
	for (NSString *key in keys) {
		NSError *error = nil;
		AVKeyValueStatus status = [asset statusOfValueForKey:key error:&error];
		if (status == AVKeyValueStatusFailed || status == AVKeyValueStatusCancelled) {
            // Error, error
			return;
		}
	}
    
    if (!asset.playable) {
        // Error
    }
    
    // Remove observer from old playerItem and create new one
    if (self.playerItem) {
        [self.playerItem removeObserver:self forKeyPath:@"status"];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem];
    }
    
    [self setPlayerItem:[AVPlayerItem playerItemWithAsset:asset]];
     
    // Observe status, ok -> play
    [self.playerItem addObserver:self
                      forKeyPath:@"status"
                         options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                         context:HSPlayerViewPlayerItemStatusObservationContext];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.playerItem
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self setSeekToZeroBeforePlay:YES]; 
                                                       }];
    
    [self setSeekToZeroBeforePlay:YES];

    // Create the player
    if (!self.player) {
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];
        
        // Observe currentItem, catch the -replaceCurrentItemWithPlayerItem:
        [self.player addObserver:self
                      forKeyPath:@"currentItem"
                         options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                         context:HSPlayerViewPlayerCurrentItemObservationContext];
        
        // Observe rate, play/pause-button?
        [self.player addObserver:self
                      forKeyPath:@"rate"
                         options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                         context:HSPlayerViewPlayerRateObservationContext];
        
    }
    
    // New playerItem?
    if (self.player.currentItem != self.playerItem) {
        [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        
        // Sync buttons
    }
    
    // Scrub to start
}

@end