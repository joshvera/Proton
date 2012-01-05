//
//  PROUniqueTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Emerald Lark. All rights reserved.
//

#import <Proton/PROUniqueTransformation.h>
#import <Proton/EXTNil.h>
#import <Proton/NSArray+HigherOrderAdditions.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROModelController.h>

@implementation PROUniqueTransformation

#pragma mark Properties

@synthesize inputValue = m_inputValue;
@synthesize outputValue = m_outputValue;

- (PROTransformation *)reverseTransformation; {
    // just flip our values around
    return [[[self class] alloc] initWithInputValue:self.outputValue outputValue:self.inputValue];
}

- (NSArray *)transformations {
    // we don't have any child transformations
    return nil;
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithInputValue:nil outputValue:nil];
}

- (id)initWithInputValue:(id)inputValue outputValue:(id)outputValue; {
    self = [super init];
    if (!self)
        return nil;

    // if both are nil, leave them nil
    // if one is nil, make it EXTNil
    // copy non-nil values
    if (inputValue) {
        m_inputValue = [inputValue copy];

        if (outputValue) {
            m_outputValue = [outputValue copy];
        } else {
            m_outputValue = [EXTNil null];
        }
    } else if (outputValue) {
        m_inputValue = [EXTNil null];
        m_outputValue = [outputValue copy];
    }

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    if (!self.inputValue)
        return obj;

    if (![self.inputValue isEqual:obj])
        return nil;

    return self.outputValue;
}

- (void)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);
    NSParameterAssert(result != nil);

    if (!modelKeyPath)
        return;

    NSString *ownedModelControllersKeyPath = [modelController modelControllersKeyPathForModelKeyPath:modelKeyPath];
    if (!ownedModelControllersKeyPath)
        return;

    NSAssert([self.outputValue isKindOfClass:[NSArray class]], @"Model controller %@ key path \"%@\" doesn't make any sense without an array at model key path \"%@\"", modelController, ownedModelControllersKeyPath, modelKeyPath);

    Class ownedModelControllerClass = [modelController modelControllerClassForModelKeyPath:modelKeyPath];

    NSArray *newControllers = [self.outputValue mapWithOptions:NSEnumerationConcurrent usingBlock:^(id model){
        return [[ownedModelControllerClass alloc] initWithModel:model];
    }];

    // replace the controllers outright, since we replaced the associated models
    // outright
    [modelController setValue:newControllers forKeyPath:ownedModelControllersKeyPath];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    id inputValue = [coder decodeObjectForKey:@"inputValue"];
    id outputValue = [coder decodeObjectForKey:@"outputValue"];
    return [self initWithInputValue:inputValue outputValue:outputValue];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.inputValue)
        [coder encodeObject:self.inputValue forKey:@"inputValue"];

    if (self.outputValue)
        [coder encodeObject:self.outputValue forKey:@"outputValue"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>{ old = %@, new = %@ }", [self class], (__bridge void *)self, self.inputValue, self.outputValue];
}

- (NSUInteger)hash {
    return [self.inputValue hash] ^ [self.outputValue hash];
}

- (BOOL)isEqual:(PROUniqueTransformation *)transformation {
    if (![transformation isKindOfClass:[PROUniqueTransformation class]])
        return NO;

    if (!NSEqualObjects(self.inputValue, transformation.inputValue))
        return NO;

    if (!NSEqualObjects(self.outputValue, transformation.outputValue))
        return NO;

    return YES;
}

@end
