//
//  HSPLayerView.m
//  HSPlayer
//
//  Created by Simon Blommegård on 2011-11-26.
//  Copyright (c) 2011 Doubleint. All rights reserved.
//

#import "HSPlayerView.h"
#import "HSSlider.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

// Constants
CGFloat const HSPlayerViewControlsAnimationDelay = .4; // ~ statusbar fade duration

// Contexts for KVO
static void *HSPlayerViewPlayerRateObservationContext = &HSPlayerViewPlayerRateObservationContext;
static void *HSPlayerViewPlayerCurrentItemObservationContext = &HSPlayerViewPlayerCurrentItemObservationContext;
static void *HSPlayerViewPlayerAirPlayVideoActiveObservationContext = &HSPlayerViewPlayerAirPlayVideoActiveObservationContext;
static void *HSPlayerViewPlayerItemStatusObservationContext = &HSPlayerViewPlayerItemStatusObservationContext;
static void *HSPlayerViewPlaterItemDurationObservationContext = &HSPlayerViewPlaterItemDurationObservationContext;
static void *HSPlayerViewPlayerLayerReadyForDisplayObservationContext = &HSPlayerViewPlayerLayerReadyForDisplayObservationContext;

@interface HSPlayerView () <UIGestureRecognizerDelegate>
@property (nonatomic, strong, readwrite) AVPlayer *player;

@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, assign) CMTime duration;

@property (nonatomic, strong) id playerTimeObserver;

@property (nonatomic, assign) BOOL seekToZeroBeforePlay;
@property (nonatomic, assign) BOOL readyForDisplayTriggered;

// Array of UIView-subclasses
@property (nonatomic, strong) NSArray *controls;

// Controls
@property (nonatomic, strong) UIView *topControlView;
@property (nonatomic, strong) UIButton *closeControlButton;
@property (nonatomic, strong) HSSlider *scrubberControlSlider;
@property (nonatomic, strong) UILabel *currentPlayerTimeLabel;
@property (nonatomic, strong) UILabel *remainingPlayerTimeLabel;

@property (nonatomic, strong) UIView *bottomControlView;
@property (nonatomic, strong) UIButton *playPauseControlButton;

// PopUps
@property (nonatomic, strong) NSMutableArray *popUps;
- (void)syncPopUps;
-(void)pauseLayer:(CALayer*)layer;
-(void)resumeLayer:(CALayer*)layer;
- (void)pausePopUps;
- (void)resumePopUps;
- (void)cleanupAllPopups;

// Gesture Recognizers
@property (nonatomic, strong) UITapGestureRecognizer *singleTapRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapRecognizer;

- (void)toggleControlsWithRecognizer:(UIGestureRecognizer *)recognizer;
- (void)toggleVideoGravityWithRecognizer:(UIGestureRecognizer *)recognizer;

- (void)doneLoadingAsset:(AVAsset *)asset withKeys:(NSArray *)keys;


- (void)addPlayerTimeObserver;
- (void)removePlayerTimeObserver;

- (void)playPause:(id)sender;
- (void)syncPlayPauseButton;

// Scrubbing
@property (nonatomic, assign, getter = isScrubbing) BOOL scrubbing;
@property (nonatomic, assign) float restoreAfterScrubbingRate;
- (void)beginScrubbing:(id)sender;
- (void)scrub:(id)sender;
- (void)endScrubbing:(id)sender;
- (void)syncScrobber;

// Custom images for controls
@property (nonatomic, strong) UIImage *playImage;
@property (nonatomic, strong) UIImage *pauseImage;
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

@synthesize controlsVisible = _controlsVisible;

@synthesize fullScreen = _fullScreen;

@synthesize controls = _controls;
@synthesize topControlView = _topControlView;
@synthesize closeControlButton = _closeControlButton;
@synthesize scrubberControlSlider = _scrubberControlSlider;
@synthesize currentPlayerTimeLabel = _currentPlayerTimeLabel;
@synthesize remainingPlayerTimeLabel = _remainingPlayerTimeLabel;

@synthesize bottomControlView = _bottomControlView;
@synthesize playPauseControlButton = _playPauseControlButton;

@synthesize popUps = _popUps;

@synthesize singleTapRecognizer = _singleTapRecognizer;
@synthesize doubleTapRecognizer = _doubleTapRecognizer;

@synthesize scrubbing = _scrubbing;
@synthesize restoreAfterScrubbingRate = _restoreAfterScrubbingRate;

@synthesize playImage = _playImage;
@synthesize pauseImage = _pauseImage;

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

+ (void)initialize {
    if (self == [HSPlayerView class]) {
        NSError *error;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    }
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self.playerLayer setOpacity:0];
        [self.playerLayer addObserver:self
                           forKeyPath:@"readyForDisplay"
                              options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                              context:HSPlayerViewPlayerLayerReadyForDisplayObservationContext];
        
        [self addGestureRecognizer:self.singleTapRecognizer];
        [self addGestureRecognizer:self.doubleTapRecognizer];
        
        // Add controls
        for (UIView *view in self.controls)
            [self addSubview:view];
        
        [self setControlsVisible:NO];
        [self setFullScreen:YES];
        
        [self setRestoreAfterScrubbingRate:1.];
    }
    
    return self;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
	if (context == HSPlayerViewPlayerItemStatusObservationContext) {
        [self syncPlayPauseButton];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerStatusUnknown: {
                [self removePlayerTimeObserver];
                [self syncScrobber];
                
                // Disable buttons & scrubber
            }
            break;
                
            case AVPlayerStatusReadyToPlay: {
                
                // Enable buttons & scrubber
                
                if (!self.isScrubbing)
                    [self play:self];
            }
            break;
                
            case AVPlayerStatusFailed: {
                [self removePlayerTimeObserver];
                [self syncScrobber];
                
                // Disable buttons & scrubber
            }
            break;
        }
	}

	else if (context == HSPlayerViewPlayerRateObservationContext) {
        [self syncPlayPauseButton];
	}
    
    // -replaceCurrentItemWithPlayerItem: && new
	else if (context == HSPlayerViewPlayerCurrentItemObservationContext) {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        // Null?
        if (newPlayerItem == (id)[NSNull null]) {
            [self removePlayerTimeObserver];
            
            // Disable buttons & scrubber
        }
        else {
            // New title
            [self syncPlayPauseButton];
            [self addPlayerTimeObserver];
        }
	}
    
    else if (context == HSPlayerViewPlaterItemDurationObservationContext) {
        [self syncScrobber];
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
    
    else if (context == HSPlayerViewPlayerAirPlayVideoActiveObservationContext) {
        // Show/hide airplay-image
    }
    
	else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)dealloc {
    [self removePlayerTimeObserver];
	
	[self.player removeObserver:self forKeyPath:@"rate"];
    [self.player removeObserver:self forKeyPath:@"currentItem"];
	[self.playerItem removeObserver:self forKeyPath:@"status"];
    [self.playerItem removeObserver:self forKeyPath:@"duration"];
    [self.playerLayer removeObserver:self forKeyPath:@"readyForDisplay"];

    if ([self.playerItem respondsToSelector:@selector(allowsAirPlayVideo)])
        [self.playerItem removeObserver:self forKeyPath:@"airPlayVideoActive"];
    
	[self.player pause];
}

#pragma mark - Properties

- (AVPlayer *)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
    [(AVPlayerLayer *) [self layer] setPlayer:player];
    
    // Optimize for airplay if possible
    if ([player respondsToSelector:@selector(allowsAirPlayVideo)]) {
        [player setAllowsAirPlayVideo:YES];
        [player setUsesAirPlayVideoWhileAirPlayScreenIsActive:YES];
        
        [player addObserver:self
                 forKeyPath:@"airPlayVideoActive"
                    options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                    context:HSPlayerViewPlayerAirPlayVideoActiveObservationContext];
    }
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

- (void)setFullScreen:(BOOL)fullScreen {
    [self willChangeValueForKey:@"fullScreen"];
    _fullScreen = fullScreen;
    [self didChangeValueForKey:@"fullScreen"];
    
    [[UIApplication sharedApplication] setStatusBarHidden:fullScreen withAnimation:UIStatusBarAnimationFade];
}

- (CMTime)duration {
    // Pefered in HTTP Live Streaming.
    if ([self.playerItem respondsToSelector:@selector(duration)] && // 4.3
        self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        if (CMTIME_IS_VALID(self.playerItem.duration))
            return self.playerItem.duration;
    }
    
    else if (CMTIME_IS_VALID(self.player.currentItem.asset.duration))
        return self.player.currentItem.asset.duration;
    
    return kCMTimeInvalid;
}

- (void)setControlsVisible:(BOOL)controlsVisible {
    [self setControlsVisible:controlsVisible animated:NO];
}

#pragma mark - Controls

- (NSArray *)controls {
    if (!_controls) {
        _controls = [NSArray arrayWithObjects:
                     self.topControlView,
                     self.bottomControlView,
                     nil];
    }
    
    return _controls;
}

- (UIView *)topControlView {
    if (!_topControlView) {
        _topControlView = [[UIView alloc] initWithFrame:CGRectMake(0., 20., self.bounds.size.width, 20.)];
        [_topControlView setBackgroundColor:[UIColor colorWithWhite:0. alpha:.5]];
        [_topControlView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth)];
        
        [self.currentPlayerTimeLabel setFrame:CGRectMake(10., 3., 55., 15.)];
        [_topControlView addSubview:self.currentPlayerTimeLabel];
        
        [self.remainingPlayerTimeLabel setFrame:CGRectMake(_topControlView.bounds.size.width-65., 3., 55., 15.)];
        [_topControlView addSubview:self.remainingPlayerTimeLabel];
        
        [self.scrubberControlSlider setFrame:CGRectMake(70., 3., self.bounds.size.width-140., 14.)];
        [_topControlView addSubview:self.scrubberControlSlider];
    }
    
    return _topControlView;
}

- (UILabel *)currentPlayerTimeLabel {
    if (!_currentPlayerTimeLabel) {
        _currentPlayerTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_currentPlayerTimeLabel setBackgroundColor:[UIColor clearColor]];
        [_currentPlayerTimeLabel setTextColor:[UIColor whiteColor]];
        [_currentPlayerTimeLabel setFont:[UIFont systemFontOfSize:12.]];
        [_currentPlayerTimeLabel setTextAlignment:UITextAlignmentCenter];
    }
    
    return _currentPlayerTimeLabel;
}

- (UILabel *)remainingPlayerTimeLabel {
    if (!_remainingPlayerTimeLabel) {
        _remainingPlayerTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_remainingPlayerTimeLabel setBackgroundColor:[UIColor clearColor]];
        [_remainingPlayerTimeLabel setTextColor:[UIColor whiteColor]];
        [_remainingPlayerTimeLabel setFont:[UIFont systemFontOfSize:12.]];
        [_remainingPlayerTimeLabel setTextAlignment:UITextAlignmentCenter];
        [_remainingPlayerTimeLabel setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin)];
    }
    
    return _remainingPlayerTimeLabel;
}

- (UIButton *)closeControlButton {
    return _closeControlButton;
}

- (HSSlider *)scrubberControlSlider {
    if (!_scrubberControlSlider) {
        _scrubberControlSlider = [[HSSlider alloc] initWithFrame:CGRectZero];
        [_scrubberControlSlider setAutoresizingMask:(UIViewAutoresizingFlexibleWidth)];
        
        [_scrubberControlSlider addTarget:self action:@selector(beginScrubbing:) forControlEvents:UIControlEventTouchDown];
        [_scrubberControlSlider addTarget:self action:@selector(scrub:) forControlEvents:UIControlEventValueChanged];
        [_scrubberControlSlider addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchUpInside];
        [_scrubberControlSlider addTarget:self action:@selector(endScrubbing:) forControlEvents:UIControlEventTouchUpOutside];
    }
    
    return _scrubberControlSlider;
}

- (UIView *)bottomControlView {
    if (!_bottomControlView) {
        _bottomControlView = [[UIView alloc] initWithFrame:CGRectMake(0., self.bounds.size.height-40., self.bounds.size.width, 40.)];
        [_bottomControlView setBackgroundColor:[UIColor colorWithWhite:0. alpha:.5]];
        [_bottomControlView setAutoresizingMask:(UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth)];

        MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(40., 11., _bottomControlView.bounds.size.width-50., 18.)];
        [volumeView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth)];
        [_bottomControlView addSubview:volumeView];
        volumeView.backgroundColor = [UIColor blueColor];

        [self.playPauseControlButton setFrame:CGRectMake(10., 10., 20., 20.)];
        [_bottomControlView addSubview:self.playPauseControlButton];
    }
    
    return _bottomControlView;
}

- (UIButton *)playPauseControlButton {
    if (!_playPauseControlButton) {
        _playPauseControlButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_playPauseControlButton setShowsTouchWhenHighlighted:YES];        
        [_playPauseControlButton setImage:self.playImage forState:UIControlStateNormal];
        [_playPauseControlButton addTarget:self action:@selector(playPause:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playPauseControlButton;
}

#pragma mark - popups

- (NSMutableArray*)popUps {
    if (!_popUps){
        _popUps = [NSMutableArray array];
    }
    
    return _popUps;
}

#pragma mark - gesture

- (UITapGestureRecognizer *)singleTapRecognizer {
    if (!_singleTapRecognizer) {
        _singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControlsWithRecognizer:)];
        // We can handle both single and double
        [_singleTapRecognizer requireGestureRecognizerToFail:self.doubleTapRecognizer];
        [_singleTapRecognizer setDelegate:self];
    }
    
    return _singleTapRecognizer;
}

- (UITapGestureRecognizer *)doubleTapRecognizer {
    if (!_doubleTapRecognizer) {
        _doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleVideoGravityWithRecognizer:)];
        [_doubleTapRecognizer setNumberOfTapsRequired:2];
        [_doubleTapRecognizer setDelegate:self];
    }
    
    return _doubleTapRecognizer;
}

#pragma mark Public

- (void)play:(id)sender {
	if (self.seekToZeroBeforePlay)  {
		[self setSeekToZeroBeforePlay:NO];
		[self.player seekToTime:kCMTimeZero];
	}
    
    [self.player play];
    [self resumePopUps];
}

- (void)pause:(id)sender {
    [self.player pause];
    [self pausePopUps];
}

- (BOOL)isPlaying {
    //	return mRestoreAfterScrubbingRate != 0.f || 
    return (self.player.rate != 0.);
}

- (void)setControlsVisible:(BOOL)controlsVisible animated:(BOOL)animated {
    [self willChangeValueForKey:@"controlsVisible"];
    _controlsVisible = controlsVisible;
    [self didChangeValueForKey:@"controlsVisible"];
    
    if (controlsVisible)
        for (UIView *view in self.controls)
            [view setHidden:NO];
    
    [UIView animateWithDuration:(animated ? HSPlayerViewControlsAnimationDelay:0.)
                          delay:0.
                        options:(UIViewAnimationCurveEaseInOut)
                     animations:^{
                         for (UIView *view in self.controls)
                             [view setAlpha:(controlsVisible ? 1.:0.)];
                     } completion:^(BOOL finished) {
                         if (!controlsVisible)
                             for (UIView *view in self.controls)
                                 [view setHidden:YES];
                     }];
    
    if (self.fullScreen)
        [[UIApplication sharedApplication] setStatusBarHidden:(!controlsVisible) withAnimation:UIStatusBarAnimationFade];
}

#pragma mark - Private

- (void)toggleControlsWithRecognizer:(UIGestureRecognizer *)recognizer {
    [self setControlsVisible:(!self.controlsVisible) animated:YES];
}

- (void)toggleVideoGravityWithRecognizer:(UIGestureRecognizer *)recognizer {
    if (self.playerLayer.videoGravity == AVLayerVideoGravityResizeAspect)
        [self.playerLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    else
        [self.playerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
}

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
    
    // Durationchange
    [self.playerItem addObserver:self
                      forKeyPath:@"duration"
                         options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                         context:HSPlayerViewPlaterItemDurationObservationContext];
    
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
        [self syncPlayPauseButton];
    }
    
    // Scrub to start
}

- (void)addPlayerTimeObserver {
    if (!_playerTimeObserver) {
        __unsafe_unretained HSPlayerView *weakSelf = self;
        id observer = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(.5, NSEC_PER_SEC)
                                                                queue:dispatch_get_main_queue()
                                                           usingBlock:^(CMTime time) {
                                                               
                                                               HSPlayerView *strongSelf = weakSelf;
                                                               if (CMTIME_IS_VALID(strongSelf.player.currentTime) && CMTIME_IS_VALID(strongSelf.duration))
                                                                   [strongSelf syncScrobber];
                                                                   [strongSelf syncPopUps];
                                                           }];
        
        [self setPlayerTimeObserver:observer];
    }
}

- (void)removePlayerTimeObserver {
    if (_playerTimeObserver) {
        [self.player removeTimeObserver:self.playerTimeObserver];
        [self setPlayerTimeObserver:nil];
    }
}

- (void)playPause:(id)sender {
    [self isPlaying] ? [self pause:sender] : [self play:sender];
}

- (void)syncPlayPauseButton {
    [self.playPauseControlButton setImage:([self isPlaying] ? self.pauseImage : self.playImage) forState:UIControlStateNormal];
}

- (void)beginScrubbing:(id)sender {
    [self removePlayerTimeObserver];
    [self setScrubbing:YES];
    [self setRestoreAfterScrubbingRate:self.player.rate];
    [self.player setRate:0.];
}

- (void)scrub:(id)sender {
    [self.player seekToTime:CMTimeMakeWithSeconds(self.scrubberControlSlider.value, NSEC_PER_SEC)];
}

- (void)endScrubbing:(id)sender {
    [self cleanupAllPopups];
    [self.player setRate:self.restoreAfterScrubbingRate];
    [self setScrubbing:NO];
    [self addPlayerTimeObserver];
}

- (void)syncScrobber {
    NSInteger currentSeconds = ceilf(CMTimeGetSeconds(self.player.currentTime)); 
    NSInteger seconds = currentSeconds % 60;
    NSInteger minutes = currentSeconds / 60;
    NSInteger hours = minutes / 60;
    
    NSInteger duration = ceilf(CMTimeGetSeconds(self.duration));
    NSInteger currentDurationSeconds = duration-currentSeconds;
    NSInteger durationSeconds = currentDurationSeconds % 60;
    NSInteger durationMinutes = currentDurationSeconds / 60;
    NSInteger durationHours = durationMinutes / 60;
    
    [self.currentPlayerTimeLabel setText:[NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds]];
    [self.remainingPlayerTimeLabel setText:[NSString stringWithFormat:@"-%02d:%02d:%02d", durationHours, durationMinutes, durationSeconds]];
    
    [self.scrubberControlSlider setMinimumValue:0.];
    [self.scrubberControlSlider setMaximumValue:duration];
    [self.scrubberControlSlider setValue:currentSeconds];
    
    //NSLog(@"%@", self.player.currentItem.seekableTimeRanges);
}

- (void)syncPopUps {
    if (CMTimeGetSeconds(self.player.currentTime) >= 4.5 && CMTimeGetSeconds(self.player.currentTime) <= 5.) {
        UILabel* pop = [[UILabel alloc] initWithFrame:CGRectMake(self.bounds.size.width, 40., 100, 60.)];
        pop.text = @"哈哈哈哈哈哈";
        [self.popUps addObject:pop];
        [self addSubview:pop];
        
        [UIView animateWithDuration:5
                         animations:^(void){
                             pop.frame = CGRectMake(-100., 40., 100, 40.);
                         }
                         completion:^(BOOL finished){
                             [pop removeFromSuperview];
                             [_popUps removeObject:pop];
                         }];
    }
}


-(void)pauseLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

-(void)resumeLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

- (void)pausePopUps {
    for (UILabel *popup in _popUps){
        [self pauseLayer:popup.layer];
    }
}

- (void)resumePopUps {
    for (UILabel *popup in _popUps){
        [self resumeLayer:popup.layer];
    }
}

- (void)cleanupAllPopups {
    for (UILabel *popup in _popUps){
        [popup.layer removeAllAnimations];
        [popup removeFromSuperview];
    }
    [_popUps removeAllObjects];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // We dont want to to hide the controls when we tap em
    for (UIView *view in self.controls)
        if (CGRectContainsPoint(view.frame, [touch locationInView:self]) && self.controlsVisible)
            return NO;

    return YES;
}

#pragma mark - Custom Images

- (UIImage *)playImage {
    if (!_playImage) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(20., 20.), NO, [[UIScreen mainScreen] scale]);
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        
        // |>
        [path moveToPoint:CGPointMake(0., 0.)];
        [path addLineToPoint:CGPointMake(20., 10.)];
        [path addLineToPoint:CGPointMake(0., 20.)];
        [path closePath];
        
        [[UIColor whiteColor] setFill];
        [path fill];
        
        _playImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return _playImage;
}

- (UIImage *)pauseImage {
    if (!_pauseImage) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(20., 20.), NO, [[UIScreen mainScreen] scale]);
        
        // ||
        UIBezierPath *path1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0., 0., 7., 20.) cornerRadius:1.];
        UIBezierPath *path2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(20.-7., 0., 7., 20.) cornerRadius:1.];
        
        [[UIColor whiteColor] setFill];
        [path1 fill];
        [path2 fill];
        
        _pauseImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return _pauseImage;
}

@end
