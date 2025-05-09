import UIKit
//import CocoaLumberjack

typealias Completion = (Bool) -> Void

let DEFAULT_ANIMATION_DURATION = 0.5
let ANIMATION_FRAME_KEY = "frame"
let ANIMATION_COLOR_KEY = "color"

class AnimationDelegate: NSObject, CAAnimationDelegate {
    var completion: Completion?
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        completion?(flag)
    }
}

class Animator: NSObject, CAAnimationDelegate {
    
    var animationDuration: Double = 0.0
    private var animationCompletions: [AnimationDelegate] = []
    
    override init() {
        super.init()
        
        self.animationCompletions = []
        animationDuration = DEFAULT_ANIMATION_DURATION
    }
    
    deinit {
        DDLogDebug("Animator dealloc")
    }
    
    @objc func clean() {
        animationCompletions.removeAll()
        UIApplication.shared.keyWindow?.layer.removeAllAnimations()
    }
    
    func startPulseAnimation(_ view: UIView?) {
        guard let view = view else { return }
        
        // Remove any existing animations
        view.layer.removeAnimation(forKey: "pulse")
        
        // Create a basic animation for scaling
        UIView.animate(withDuration: 1.0, delay: 0, options: [.autoreverse, .repeat], animations: {
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: nil)
    }

    func stopPulseAnimation(_ view: UIView?) {
        guard let view = view else { return }
        
        // Stop animation and reset transform
        view.layer.removeAnimation(forKey: "pulse")
        UIView.animate(withDuration: 0.3, animations: {
            view.transform = CGAffineTransform.identity
        })
    }

    func animate(_ view: UIView?, toFrame frame: CGRect) {
        animate(view, toFrame: frame) { (bool) in }
    }

    func animate(_ view: UIView?, toFrame frame: CGRect, completion: @escaping Completion) {
        guard let view = view else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        if frame.equalTo(view.frame) {
            DispatchQueue.main.async { completion(false) }
            return
        }

        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut, animations: {
            view.frame = frame
        }) { finished in
            completion(finished)
        }
    }

    @objc func animate(_ view: UIView?, toFade fade: Bool) {
        animate(view, toFade: fade) { (bool) in }
    }

    func animate(_ view: UIView?, toFade fade: Bool, completion: @escaping Completion) {
        guard let view = view else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        let newOpacity: CGFloat = fade ? 0 : 1
        
        if CGFloat(view.layer.opacity) == newOpacity {
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        UIView.animate(withDuration: animationDuration, animations: {
            view.layer.opacity = Float(newOpacity)
        }) { finished in
            completion(finished)
        }
    }

    func animate(_ view: UIView?, to color: UIColor?) {
        guard let view = view, let color = color else { return }
        
        if view.backgroundColor == color {
            return
        }
        
        let oldColor = view.backgroundColor ?? UIColor.clear
        
        UIView.animate(withDuration: animationDuration) {
            view.backgroundColor = color
        }
    }
}
