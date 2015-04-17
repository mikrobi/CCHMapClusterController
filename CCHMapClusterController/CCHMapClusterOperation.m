//
//  CCHMapClusterOperation.m
//  CCHMapClusterController
//
//  Copyright (C) 2014 Claus Höfele
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "CCHMapClusterOperation.h"

#import "CCHMapTree.h"
#import "CCHMapClusterAnnotation.h"
#import "CCHMapClusterControllerUtils.h"
#import "CCHCenterOfMassMapClusterer.h"
#import "CCHMapAnimator.h"
#import "CCHMapClusterControllerDelegate.h"

@interface CCHMapClusterOperation()

@property (nonatomic) MKMapView *mapView;
@property (nonatomic) double clusterSize;
@property (nonatomic) double marginFactor;
@property (nonatomic) MKCoordinateRegion mapViewRegion;
@property (nonatomic) CGFloat mapViewWidth;
@property (nonatomic, copy) NSArray *mapViewAnnotations;
@property (nonatomic) BOOL reuseExistingClusterAnnotations;
@property (nonatomic) double maxZoomLevelForClustering;
@property (nonatomic) NSUInteger minUniqueLocationsForClustering;

@property (nonatomic, getter = isExecuting) BOOL executing;
@property (nonatomic, getter = isFinished) BOOL finished;

@end

@implementation CCHMapClusterOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithMapView:(MKMapView *)mapView clusterSize:(double)clusterSize marginFactor:(double)marginFactor reuseExistingClusterAnnotations:(BOOL)reuseExistingClusterAnnotation maxZoomLevelForClustering:(double)maxZoomLevelForClustering minUniqueLocationsForClustering:(NSUInteger)minUniqueLocationsForClustering
{
    self = [super init];
    if (self) {
        _mapView = mapView;
        _clusterSize = clusterSize;
        _marginFactor = marginFactor;
        _mapViewRegion = mapView.region;
        _mapViewWidth = mapView.bounds.size.width;
        _mapViewAnnotations = mapView.annotations;
        _reuseExistingClusterAnnotations = reuseExistingClusterAnnotation;
        _maxZoomLevelForClustering = maxZoomLevelForClustering;
        // TODO: Consider minUniqueLocationsForClustering in CCHMapClusterOperation with new distance algorithm (if needed)
        _minUniqueLocationsForClustering = minUniqueLocationsForClustering;
        
        _executing = NO;
        _finished = NO;
    }
    
    return self;
}

- (MKMapRect)clusteringMapRect
{
    MKMapRect visibleMapRect = _mapView.visibleMapRect;
    MKMapRect mapRect = MKMapRectInset(visibleMapRect, -_marginFactor * visibleMapRect.size.width, -_marginFactor * visibleMapRect.size.height);
    return MKMapRectIntersection(mapRect, MKMapRectWorld);
}

- (MKZoomScale) currentZoomScale
{
    CGSize screenSize = _mapView.bounds.size;
    MKMapRect mapRect = _mapView.visibleMapRect;
    MKZoomScale zoomScale = screenSize.width / mapRect.size.width;
    return zoomScale;
}

+ (double) distanceSquared:(MKMapPoint)a b:(MKMapPoint)b {
    return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y);
}


+ (MKMapRect) createBoundsFromSpan:(MKMapPoint)p span:(double)span {
    double halfSpan = span / 2;
    return MKMapRectMake(p.x - halfSpan, p.y - halfSpan, span, span);
}

- (void)start
{
    _executing = YES;
    
    double zoomLevel = CCHMapClusterControllerZoomLevelForRegion(_mapViewRegion.center.longitude, _mapViewRegion.span.longitudeDelta, _mapViewWidth);
    BOOL disableClustering = (zoomLevel > _maxZoomLevelForClustering);
    BOOL respondsToSelector = [_clusterControllerDelegate respondsToSelector:@selector(mapClusterController:willReuseMapClusterAnnotation:)];
    
    // Zoom scale * MK distance = screen points
    MKZoomScale zoomScale = [self currentZoomScale];
    // The width and height of the square around a point that we'll consider later
    double zoomSpecificSpan = _clusterSize / zoomScale;
    // Annotations we've already looked at for a starting point for a cluster
    NSMutableSet *visitedCandidates = [[NSMutableSet alloc] init];
    
    // The MKAnnotations (single POIs and clusters alike) we want on display
    NSMutableSet *clusters = [[NSMutableSet alloc] init];
    NSMutableSet *reusedClusters = [[NSMutableSet alloc] init];
    
    // Map a single POI MKAnnotation to its distance (NSNumber*) from its cluster (if added to one yet)
    NSMapTable *distanceToCluster = [NSMapTable strongToStrongObjectsMapTable];
    
    // Map a single POI MKAnnotation to its cluster annotation (if added to one yet)
    NSMapTable *itemToCluster = [NSMapTable strongToStrongObjectsMapTable];
    
    NSSet *allAnnotationsInGrid = [_allAnnotationsMapTree annotationsInMapRect:[self clusteringMapRect]];
    NSMutableSet *reusableAnnotations = [NSMutableSet setWithSet:_visibleAnnotationsMapTree.annotations];
    
    for (id<MKAnnotation> candidate in allAnnotationsInGrid) {
        if ([visitedCandidates containsObject:candidate]) {
            continue;
        }
        
        MKMapPoint point = MKMapPointForCoordinate(candidate.coordinate);
        MKMapRect searchBounds = [self.class createBoundsFromSpan:point span:zoomSpecificSpan];
        
        CCHMapClusterAnnotation *cluster;
        if (_reuseExistingClusterAnnotations) {
            cluster = CCHMapClusterControllerFindVisibleAnnotation([NSSet setWithObject:candidate], reusableAnnotations);
        }
        if (cluster == nil) {
            cluster = [[CCHMapClusterAnnotation alloc] init];
            cluster.mapClusterController = _clusterController;
            cluster.delegate = _clusterControllerDelegate;
        } else {
            [reusableAnnotations removeObject:cluster];
            [reusedClusters addObject:cluster];
        }
        cluster.annotations = [[NSSet alloc] init];
        [clusters addObject:cluster];
        
        NSSet *annotationsInSearchBounds = [_allAnnotationsMapTree annotationsInMapRect:searchBounds];
        if (disableClustering || annotationsInSearchBounds.count == 1) {
            // Only the current candidate is in range.
            cluster.annotations = [cluster.annotations setByAddingObject:candidate];
            [visitedCandidates addObject:candidate];
            [distanceToCluster setObject:[NSNumber numberWithDouble:0.0] forKey:candidate];
            continue;
        }
        
        // Iterate for annotation in the bounds box
        for (id<MKAnnotation> annotation in annotationsInSearchBounds) {
            // This item may already be associated with another cluster,
            // in which case we can know its distance from that cluster
            NSNumber *existingDistance = [distanceToCluster objectForKey:annotation];
            
            // Get distance from the new cluster location we're working on
            double distance = [self.class distanceSquared:MKMapPointForCoordinate(annotation.coordinate) b:MKMapPointForCoordinate(candidate.coordinate)];
            
            if (existingDistance != nil) {
                // Item already belongs to another cluster. Check if it's closer to this cluster.
                if ([existingDistance doubleValue] <= distance) {
                    continue;
                }
                // Remove from previous cluster.
                CCHMapClusterAnnotation *prevCluster = [itemToCluster objectForKey:annotation];
                if (prevCluster != nil) {
                    NSMutableSet *set = [NSMutableSet setWithSet:prevCluster.annotations];
                    [set minusSet:[NSSet setWithObject:annotation]];
                    prevCluster.annotations = set;
                }
            }
            // Record new distance
            [distanceToCluster setObject:[NSNumber numberWithDouble:distance] forKey:annotation];
            // Add item to the cluster we're working on
            cluster.annotations = [cluster.annotations setByAddingObject:annotation];
            // Update mapping in our item-to-cluster map.
            [itemToCluster setObject:cluster forKey:annotation];
        }
        // Mark all of them visited so we don't start considering them again
        [visitedCandidates addObjectsFromArray:[annotationsInSearchBounds allObjects]];
    }
    
    //set center coordinate of clusters
    CCHCenterOfMassMapClusterer *clusterer = [[CCHCenterOfMassMapClusterer alloc] init];
    NSMutableSet *nonReusedClusters = [NSMutableSet setWithSet:clusters];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [nonReusedClusters minusSet:reusedClusters];
        for (CCHMapClusterAnnotation *cluster in nonReusedClusters) {
            cluster.coordinate = [clusterer mapClusterController:_clusterController coordinateForAnnotations:cluster.annotations inMapRect:MKMapRectNull];
        }
        //update annotation view's of clusters that we've reused
        for (CCHMapClusterAnnotation *cluster in reusedClusters) {
            CLLocationCoordinate2D center = [clusterer mapClusterController:_clusterController coordinateForAnnotations:cluster.annotations inMapRect:MKMapRectNull];
            if (cluster.coordinate.latitude != center.latitude || cluster.coordinate.longitude != center.longitude) {
                cluster.coordinate = center;
            }
            cluster.title = nil;
            cluster.subtitle = nil;
            if (respondsToSelector) {
                [_clusterControllerDelegate mapClusterController:_clusterController willReuseMapClusterAnnotation:cluster];
            }
        }
    });
    
    // Figure out difference between new and old clusters
    NSSet *annotationsBeforeAsSet = CCHMapClusterControllerClusterAnnotationsForAnnotations(self.mapViewAnnotations, self.clusterController);
    NSMutableSet *annotationsToKeep = [NSMutableSet setWithSet:annotationsBeforeAsSet];
    [annotationsToKeep intersectSet:clusters];
    NSMutableSet *annotationsToAddAsSet = [NSMutableSet setWithSet:clusters];
    [annotationsToAddAsSet minusSet:annotationsToKeep];
    NSArray *annotationsToAdd = [annotationsToAddAsSet allObjects];
    NSMutableSet *annotationsToRemoveAsSet = [NSMutableSet setWithSet:annotationsBeforeAsSet];
    [annotationsToRemoveAsSet minusSet:clusters];
    NSArray *annotationsToRemove = [annotationsToRemoveAsSet allObjects];
    
    // Show cluster annotations on map
    [_visibleAnnotationsMapTree removeAnnotations:annotationsToRemove];
    [_visibleAnnotationsMapTree addAnnotations:annotationsToAdd];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_clusterControllerDelegate respondsToSelector:@selector(mapClusterController:willAddClusterAnnotations:)]) {
            [_clusterControllerDelegate mapClusterController:_clusterController willAddClusterAnnotations:annotationsToAdd];
        }
        [self.mapView addAnnotations:annotationsToAdd];
        if ([_clusterControllerDelegate respondsToSelector:@selector(mapClusterController:willRemoveClusterAnnotations:)]) {
            [_clusterControllerDelegate mapClusterController:_clusterController willRemoveClusterAnnotations:annotationsToRemove];
        }
        [self.animator mapClusterController:self.clusterController willRemoveAnnotations:annotationsToRemove withCompletionHandler:^{
            [self.mapView removeAnnotations:annotationsToRemove];
            
            self.executing = NO;
            self.finished = YES;
        }];
    });
}

- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    _finished = YES;
    [self didChangeValueForKey:@"isFinished"];
}

@end
