//
//  ElasticPullToUpdate.swift
//  ElasticPullToUpdate
//
//  Created by Mikhail Stepkin on 19.05.16.
//  Copyright © 2016 Ramotion. All rights reserved.
//

import UIKit
import Refresher

/**
 # Elastic pull to update
 ----
 Elastic pull animator for [`Refresher`](https://github.com/jcavar/refresher).
 
 - Requires:
 ```
 pod 'Refresher'
 ```
 
 ### Usage:
 ```
 tableView.addPullToRefreshWithAction({
    yourAsyncRefreshingCall(…, callback: {
        …
        self.tableView.stopPullToRefresh()
        …
    })
 }, withAnimator: ElasticPullToUpdate(…))
 ```
 */
public class ElasticPullToUpdate: UIView, PullToRefreshViewDelegate {
    private static let iota = 0.01
    
    /// Set the pulling down threshold. Value is between `0.0` and `1.0`.
    public var threshold: CGFloat = 0.5 {
        didSet {
            if threshold < 0.0 {
                threshold = 0.0
            }
            
            if threshold > 1.0 {
                threshold = 1.0
            }
        }
    }
    
    private let shapeLayer    = CAShapeLayer()
    private let circleLayer   = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    
    private var radius: CGFloat {
        return self.frame.height / 5
    }
    
    private var progressLineWidth: CGFloat {
        return self.radius / 10
    }
    
    // MARK: - PullToRefreshViewDelegate methods:
    
    /**
     PullToRefreshViewDelegate method.
     Is called when refreshing animation starts.
     
     - warning: Should **not** be called directly.
     */
    public func pullToRefreshAnimationDidStart(view: PullToRefreshView) {
        let borderY  = bounds.maxY
        let controlY = borderY - bounds.height * threshold
        
        let innerBowPath = UIBezierPath()
        innerBowPath.moveToPoint(CGPoint(x: bounds.minX, y: bounds.minY))
        innerBowPath.addLineToPoint(CGPoint(x: bounds.maxX, y: bounds.minY))
        innerBowPath.addLineToPoint(CGPoint(x: bounds.maxX, y: borderY))
        innerBowPath.addQuadCurveToPoint(CGPoint(x: bounds.minX, y: borderY), controlPoint: CGPoint(x: bounds.midX, y: controlY))
        innerBowPath.addLineToPoint(CGPoint(x: bounds.minX, y: bounds.minY))
        
        let flatPath = UIBezierPath(rect: self.bounds)
        
        let bounceAnimation = CAKeyframeAnimation(keyPath: "path")
        bounceAnimation.values = [shapeLayer.path ?? innerBowPath.CGPath, innerBowPath.CGPath, flatPath.CGPath]
        bounceAnimation.keyTimes = [0.0, 0.75, 1.0]
        bounceAnimation.duration = 0.5
        shapeLayer.addAnimation(bounceAnimation, forKey: "path")
        
        shapeLayer.path = flatPath.CGPath
        
        let maskLayer = CAShapeLayer(layer: shapeLayer)
        maskLayer.addAnimation(bounceAnimation, forKey: "path")
        maskLayer.path = shapeLayer.path
        
        self.layer.mask = maskLayer
        
        
        let circleRect = CGRect(
            origin: CGPoint(
                x: bounds.midX - radius,
                y: bounds.midY - radius
            ),
            size: CGSize(
                width: 2 * radius,
                height: 2 * radius
            ))
        let circlePath = UIBezierPath(ovalInRect: circleRect)
        circleLayer.path = circlePath.CGPath
        circleLayer.fillColor = UIColor.whiteColor().CGColor
        
        self.layer.addSublayer(circleLayer)
        
        progressLayer.fillColor   = UIColor.clearColor().CGColor
        progressLayer.strokeColor = UIColor.whiteColor().CGColor
        progressLayer.lineWidth   = progressLineWidth
        progressLayer.lineCap     = kCALineCapRound
        
        let circleCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        let progressPath = UIBezierPath()
        progressPath.addArcWithCenter(circleCenter,
                                      radius: radius + progressLineWidth,
                                      startAngle: CGFloat(M_PI_2) - progressLineWidth/radius/2,
                                      endAngle: CGFloat(M_PI_2) + CGFloat(arc4random_uniform(100)/10),
                                      clockwise: progress.major > progress.minor
        )
        progressLayer.path = progressPath.CGPath
        
        self.layer.addSublayer(progressLayer)
        
        let circleAnimation = CAKeyframeAnimation(keyPath: "transform")
        circleAnimation.values = [2 * bounds.height, bounds.height, 0].map { NSValue(CATransform3D: CATransform3DMakeTranslation(0, $0, 0) ) }
        circleAnimation.keyTimes = [0.0, 0.5, 1.0]
        circleAnimation.duration  = bounceAnimation.duration
        
        circleLayer.transform = CATransform3DIdentity
        circleLayer.position  = .zero
        circleLayer.addAnimation(circleAnimation, forKey: "transform")
        
        progressLayer.transform = CATransform3DIdentity
        progressLayer.position  = .zero
        progressLayer.addAnimation(circleAnimation, forKey: "transform")
        
        self.animateProgress()
        
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(circleAnimation.duration * 1100) * Int64(NSEC_PER_MSEC))
        dispatch_after(when, dispatch_get_main_queue()) {
            self.animationTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(ElasticPullToUpdate.iota), target: self, selector: #selector(self.animateProgress), userInfo: nil, repeats: true)
        }
    }
    
    private var animationTimer: NSTimer?
    
    /**
     PullToRefreshViewDelegate method.
     Is called when refreshing animation ends.
     
     - warning: Should **not** be called directly.
     */
    public func pullToRefreshAnimationDidEnd(view: PullToRefreshView) {
        animationTimer?.invalidate()
        progress = (0, 0)
        
        circleLayer.removeAllAnimations()
        progressLayer.removeAllAnimations()
        
        [
            shapeLayer,
            circleLayer,
            progressLayer,
            ]
            .forEach { $0.removeFromSuperlayer() }
    }
    
    /**
     PullToRefreshViewDelegate method.
     Is called when user is interactively pulling down.
     
     - warning: Should **not** be called directly.
     - parameter progress: Pulling down progress.
     */
    public func pullToRefresh(view: PullToRefreshView, progressDidChange progress: CGFloat) {
        self.superview?.bringSubviewToFront(self)
        
        let toPath: UIBezierPath
        if progress >= threshold {
            let coef: CGFloat = min(1.0, (progress - threshold))
            let borderY  = bounds.maxY
            let controlY = borderY + bounds.height * coef
            
            let path = UIBezierPath()
            path.moveToPoint(CGPoint(x: bounds.minX, y: bounds.minY))
            path.addLineToPoint(CGPoint(x: bounds.maxX, y: bounds.minY))
            path.addLineToPoint(CGPoint(x: bounds.maxX, y: borderY))
            path.addQuadCurveToPoint(CGPoint(x: bounds.minX, y: borderY), controlPoint: CGPoint(x: bounds.midX, y: controlY))
            path.addLineToPoint(CGPoint(x: bounds.minX, y: bounds.minY))
            
            toPath = path
        } else {
            toPath = UIBezierPath(rect: bounds)
        }
        
        shapeLayer.path = toPath.CGPath
        self.layer.addSublayer(shapeLayer)
        
        let maskLayer = CAShapeLayer(layer: shapeLayer)
        maskLayer.path = shapeLayer.path
        
        self.layer.mask = maskLayer
        
        if let superColor = superview?.backgroundColor where superColor.colorWithAlphaComponent(0.0) == superColor {
            superview?.backgroundColor = UIColor.whiteColor()
        }
        
        let fillColor: UIColor = superview?.superview?.backgroundColor ?? UIColor.lightGrayColor()
        
        shapeLayer.fillColor = fillColor.CGColor
    }
    
    private var pullState: PullToRefreshViewState?
    /**
     PullToRefreshViewDelegate method.
     Is called when pulling state changes.
     
     - warning: Should **not** be called directly.
     - parameter state: Pulling down state.
     */
    public func pullToRefresh(view: PullToRefreshView, stateDidChange state: PullToRefreshViewState) {
        self.pullState = state
    }
    
    private var progress: (major: CGFloat, minor: CGFloat) = (0.0, 0.0)
    
    @objc
    private func animateProgress() -> Void {
        let circleCenter = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        
        progress.major += CGFloat(ElasticPullToUpdate.iota)
        progress.minor = progress.major - 0.75 * abs(sin(progress.major))
        
        let progressPath = UIBezierPath()
        progressPath.addArcWithCenter(circleCenter,
                                      radius: self.radius + self.progressLineWidth,
                                      startAngle: CGFloat(M_PI_2) + CGFloat(2 * M_PI) * self.progress.minor,
                                      endAngle: CGFloat(M_PI_2) + CGFloat(2 * M_PI) * self.progress.major,
                                      clockwise: true
        )
        
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = self.progressLayer.path
        animation.toValue   = progressPath
        animation.duration  = 0.1
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        self.progressLayer.addAnimation(animation, forKey: "path")
        
        self.progressLayer.path = progressPath.CGPath
    }
    
}