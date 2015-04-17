//
//  CCHClusterTrackerPayload.m
//  CCHMapClusterController Example iOS
//
//  Created by Jakob Class on 01/04/15.
//  Copyright (c) 2015 Claus Höfele. All rights reserved.
//

#import <objc/runtime.h>
#import <MapKit/MapKit.h>
#import "MKAnnotation+CCHClusterTracker.h"

static char const* const tag = "CCHClusterTracker";

@class CCHMapClusterAnnotation;

/**
 Private object to keep an extra payload for objects conform to MKAnnotation protocol.
 */
@interface CCHClusterTrackerPayload : NSObject
@property (nonatomic, weak) CCHMapClusterAnnotation *cluster;
@property (nonatomic, assign) CLLocationCoordinate2D previousCoordinate;
@property (nonatomic, assign) CLLocationCoordinate2D newCoordinate;
@end

@implementation CCHClusterTrackerPayload

- (id)init
{
    self = [super init];
    if (self) {
        _previousCoordinate = kCLLocationCoordinate2DInvalid;
        _newCoordinate = kCLLocationCoordinate2DInvalid;
    }
    return self;
}

@end

@implementation NSObject (CCHClusterTracker)

- (CCHClusterTrackerPayload *)cch_helper
{
    NSAssert([self conformsToProtocol:@protocol(MKAnnotation)], @"Must conform to protocol");
    CCHClusterTrackerPayload *payload = objc_getAssociatedObject(self, tag);
    
    if (!payload) {
        payload = [[CCHClusterTrackerPayload alloc] init];
        objc_setAssociatedObject(self, tag, payload, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return payload;
}

- (void)cch_setCluster:(CCHMapClusterAnnotation *)cluster
{
    CCHClusterTrackerPayload *payload = [self cch_helper];
    payload.cluster = cluster;
}

- (CCHMapClusterAnnotation *)cch_cluster
{
    CCHClusterTrackerPayload *payload = [self cch_helper];
    return  payload.cluster;
}

#pragma mark Unused

- (void)cch_setPreviousCoordinate:(CLLocationCoordinate2D)coordinate
{
    CCHClusterTrackerPayload *payload = [self cch_helper];
    payload.previousCoordinate = coordinate;
}

- (CLLocationCoordinate2D)cch_previousCoordinate
{
    CCHClusterTrackerPayload *payload = [self cch_helper];
    return payload.previousCoordinate;
}

- (void)cch_setNewCoordinate:(CLLocationCoordinate2D)coordinate
{
    CCHClusterTrackerPayload *payload = [self cch_helper];
    payload.newCoordinate = coordinate;
}

- (CLLocationCoordinate2D)cch_newCoordinate
{
    CCHClusterTrackerPayload *payload = [self cch_helper];
    return payload.newCoordinate;
}

@end
