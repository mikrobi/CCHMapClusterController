//
//  CCHMoveInOutMapAnimator.m
//  CCHMapClusterController Example iOS
//
//  Created by Jakob Class on 01/04/15.
//  Copyright (c) 2015 Claus Höfele. All rights reserved.
//

#import "CCHMoveInOutMapAnimator.h"

#import "CCHMapClusterController.h"
#import "CCHMapClusterAnnotation.h"
#import "MKAnnotation+CCHClusterTracker.h"
#import <MapKit/MapKit.h>

@implementation CCHMoveInOutMapAnimator

- (id)init
{
    self = [super init];
    if (self) {
        self.duration = 0.5;
    }
    return self;
}

- (void)mapClusterController:(CCHMapClusterController *)mapClusterController didAddAnnotationViews:(NSArray *)annotationViews
{
    // Animate annotations that get added
#if TARGET_OS_IPHONE
    NSMutableArray *coords = [NSMutableArray arrayWithCapacity:[annotationViews count]];
    
    for (MKAnnotationView *annotationView in annotationViews)
    {
        NSObject <MKAnnotation> *annotation = annotationView.annotation;
        CCHMapClusterAnnotation *cluster = [annotation cch_cluster];
        if (cluster) {
            [coords addObject:[NSValue valueWithMKCoordinate:annotation.coordinate]];
            [annotation setCoordinate:cluster.coordinate];
        }
    }
    [UIView animateWithDuration:self.duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
        int i=0;
        for (MKAnnotationView *annotationView in annotationViews) {
            NSObject <MKAnnotation> *annotation = annotationView.annotation;
            CCHMapClusterAnnotation *cluster = [annotation cch_cluster];
            if (cluster) {
                [annotation setCoordinate:[coords[i++] MKCoordinateValue]];
                [annotation cch_setCluster:nil];
            }
            annotationView.alpha = 1.0;
        }
    } completion:nil];
#endif
}

- (void)mapClusterController:(CCHMapClusterController *)mapClusterController willRemoveAnnotations:(NSArray *)annotations withCompletionHandler:(void (^)())completionHandler
{
#if TARGET_OS_IPHONE
    MKMapView *mapView = mapClusterController.mapView;
    [UIView animateWithDuration:self.duration delay:0 options:UIViewAnimationCurveEaseInOut animations:^{
        for (NSObject<MKAnnotation> *annotation in annotations) {
            CCHMapClusterAnnotation *cluster = [annotation cch_cluster];
            if (cluster) {
                [annotation setCoordinate:cluster.coordinate];
            }
            
            MKAnnotationView *annotationView = [mapView viewForAnnotation:annotation];
            annotationView.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        if (completionHandler) {
            completionHandler();
        }
    }];
#else
    if (completionHandler) {
        completionHandler();
    }
#endif
}

@end