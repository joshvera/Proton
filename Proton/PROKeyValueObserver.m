//
//  PROKeyValueObserver.m
//  Proton
//
//  Created by Justin Spahr-Summers on 23.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import "PROKeyValueObserver.h"
#import "EXTScope.h"
#import "SDQueue.h"

/*
 * A unique context pointer for our class, so that we can uniquely identify
 * observations that we set up.
 */
static void * const PROKeyValueObserverContext = "PROKeyValueObserverContext";

@interface PROKeyValueObserver ()
@property (getter = isExecuting, readwrite) BOOL executing;
@end

@implementation PROKeyValueObserver

#pragma mark Properties

@synthesize target = m_target;
@synthesize keyPath = m_keyPath;
@synthesize block = m_block;
@synthesize options = m_options;
@synthesize queue = m_queue;
@synthesize executing = m_executing;

#pragma mark Initialization

- (id)init {
    return [self initWithTarget:nil keyPath:nil block:nil];
}

- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath block:(PROKeyValueObserverBlock)block; {
    return [self initWithTarget:target keyPath:keyPath options:0 block:block];
}

- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(PROKeyValueObserverBlock)block; {
    self = [super init];
    if (!self)
        return nil;

    m_target = target;
    m_keyPath = [keyPath copy];
    m_options = options;
    m_block = [block copy];

    self.queue = [SDQueue mainQueue];
    [self.target addObserver:self forKeyPath:self.keyPath options:self.options context:PROKeyValueObserverContext];

    return self;
}

- (void)dealloc {
    [self.target removeObserver:self forKeyPath:self.keyPath context:PROKeyValueObserverContext];
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>( target = %@, keyPath = %@ )", [self class], (__bridge void *)self, self.target, self.keyPath];
}

#pragma mark NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)changes context:(void *)context {
    NSAssert([keyPath isEqualToString:self.keyPath], @"%@ should not be receiving change notifications for a key path other than its own", self);
    NSAssert(context == PROKeyValueObserverContext, @"%@ should not be receiving change notifications for a context other than its own", self);

    PROKeyValueObserverBlock block = self.block;

    void (^trampoline)(void) = ^{
        self.executing = YES;

        // using @onExit ensures that we set the flag back to NO even in the
        // face of an exception
        @onExit {
            self.executing = NO;
        };

        block(changes);
    };

    SDQueue *queue = self.queue;

    if (!queue || [queue isCurrentQueue])
        trampoline();
    else
        [queue runAsynchronously:trampoline];
}

@end
