//
//  CCHClusterTrackerPayload.h
//  CCHMapClusterController Example iOS
//
//  Created by Jakob Class on 01/04/15.
//  Copyright (c) 2015 Claus Höfele. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CCHMapClusterAnnotation;

/**
 Add a weak reference to the parent cluster (and eventually more payload).
 Note:
 It's not a real MKAnnotation category: since it is a protocol we extend
 NSObject and check at runtime if the object conform to protocol MKAnnotation
 */
@interface NSObject (CCHClusterTracker)

- (void)cch_setCluster:(CCHMapClusterAnnotation *)cluster;
- (CCHMapClusterAnnotation *)cch_cluster;

// These methods are not used yet .. maybe we dont need them
- (void)cch_setPreviousCoordinate:(CLLocationCoordinate2D)coordinate;
- (CLLocationCoordinate2D)cch_previousCoordinate;
- (void)cch_setNewCoordinate:(CLLocationCoordinate2D)coordinate;
- (CLLocationCoordinate2D)cch_newCoordinate;

@end