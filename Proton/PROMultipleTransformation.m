//
//  PROMultipleTransformation.m
//  Proton
//
//  Created by Justin Spahr-Summers on 13.12.11.
//  Copyright (c) 2011 Bitswift. All rights reserved.
//

#import <Proton/PROMultipleTransformation.h>
#import <Proton/EXTNil.h>
#import <Proton/NSObject+ComparisonAdditions.h>
#import <Proton/PROKeyValueCodingMacros.h>
#import <Proton/PROModelController.h>

@implementation PROMultipleTransformation

#pragma mark Properties

@synthesize transformations = m_transformations;

- (PROTransformation *)reverseTransformation; {
    NSMutableArray *reverseTransformations = [[NSMutableArray alloc] initWithCapacity:self.transformations.count];

    // reverse each individual transformation, and reverse their order as well
    [self.transformations enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PROTransformation *transformation, NSUInteger index, BOOL *stop){
        [reverseTransformations addObject:transformation.reverseTransformation];
    }];
    
    return [[[self class] alloc] initWithTransformations:reverseTransformations];
}

#pragma mark Lifecycle

- (id)init; {
    return [self initWithTransformations:nil];
}

- (id)initWithTransformations:(NSArray *)transformations; {
    self = [super init];
    if (!self)
        return nil;

    if (!transformations) {
        // the contract from PROTransformation says that the 'transformations'
        // property can never be nil for this class
        m_transformations = [NSArray array];
    } else {
        m_transformations = [transformations copy];
    }

    return self;
}

#pragma mark Transformation

- (id)transform:(id)obj; {
    id currentValue = obj;

    for (PROTransformation *transformation in self.transformations) {
        currentValue = [transformation transform:currentValue];
        if (!currentValue)
            return nil;
    }

    return currentValue;
}

- (BOOL)updateModelController:(PROModelController *)modelController transformationResult:(id)result forModelKeyPath:(NSString *)modelKeyPath; {
    NSParameterAssert(modelController != nil);

    /*
     * Unfortunately, for a multiple transformation, we have to redo the
     * actual work of the transformation in order to properly update the model
     * controller step-by-step. It would be unsafe to update it just with the
     * final result, because the child transformations may be granular and
     * independent enough that they need to be separately applied one-by-one.
     */

    // obtain the key path to the model, relative to the model controller, so
    // that we can read the existing value
    NSString *fullModelKeyPath = PROKeyForObject(modelController, model);
    if (modelKeyPath)
        fullModelKeyPath = [fullModelKeyPath stringByAppendingFormat:@".%@", modelKeyPath];

    id currentValue = [modelController valueForKeyPath:fullModelKeyPath];
    if (!currentValue)
        currentValue = [EXTNil null];

    #ifdef DEBUG
    id originalResultValue = (result ?: [EXTNil null]);

    NSAssert([[self transform:currentValue] isEqual:originalResultValue], @"Model at key path \"%@\" on %@ does not match the original value passed into %@", modelKeyPath, modelController, self);
    #endif

    for (PROTransformation *transformation in self.transformations) {
        currentValue = [transformation transform:currentValue];

        id subResult = currentValue;
        if ([subResult isEqual:[EXTNil null]])
            subResult = nil;

        if (![transformation updateModelController:modelController transformationResult:currentValue forModelKeyPath:modelKeyPath]) {
            // some model propagation failed, so just set the top-level object
            // after all
            modelController.model = result;
            break;
        }
    }

    return YES;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
    NSArray *transformations = [coder decodeObjectForKey:@"transformations"];
    return [self initWithTransformations:transformations];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    if (self.transformations)
        [coder encodeObject:self.transformations forKey:@"transformations"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    // this object is immutable
    return self;
}

#pragma mark NSObject overrides

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p>: %@", [self class], (__bridge void *)self, self.transformations];
}

- (NSUInteger)hash {
    return [self.transformations hash];
}

- (BOOL)isEqual:(PROMultipleTransformation *)transformation {
    if (![transformation isKindOfClass:[PROMultipleTransformation class]])
        return NO;

    return NSEqualObjects(self.transformations, transformation.transformations);
}

@end