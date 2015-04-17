//
//  CCHMoveInOutMapAnimator.h
//  CCHMapClusterController Example iOS
//
//  Created by Jakob Class on 01/04/15.
//  Copyright (c) 2015 Claus Höfele. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CCHMapAnimator.h"

@interface CCHMoveInOutMapAnimator : NSObject<CCHMapAnimator>

@property (nonatomic, assign) NSTimeInterval duration;

- (void)mapClusterController:(CCHMapClusterController *)mapClusterController didAddAnnotationViews:(NSArray *)annotationViews;
- (void)mapClusterController:(CCHMapClusterController *)mapClusterController willRemoveAnnotations:(NSArray *)annotations withCompletionHandler:(void (^)())completionHandler;

@end
