//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

import UIKit

@objc class AudioProgressView: UIView {

    override var bounds: CGRect {
        didSet {
            if oldValue != bounds {
                updateSubviews()
            }
        }
    }

    override var frame: CGRect {
        didSet {
            if oldValue != frame {
                updateSubviews()
            }
        }
    }

    var horizontalBarColor = UIColor.black {
        didSet {
            updateContent()
        }
    }

    var progressColor = UIColor.blue {
        didSet {
            updateContent()
        }
    }

    private let horizontalBarLayer: CAShapeLayer
    private let progressLayer: CAShapeLayer

    var progress: CGFloat = 0 {
        didSet {
            if oldValue != progress {
                updateContent()
            }
        }
    }

    @available(*, unavailable, message:"use init() constructor instead.")
    required init?(coder aDecoder: NSCoder) {
        self.horizontalBarLayer = CAShapeLayer()
        self.progressLayer = CAShapeLayer()

        super.init(coder: aDecoder)

        assertionFailure()
    }

    public required init() {
        self.horizontalBarLayer = CAShapeLayer()
        self.progressLayer = CAShapeLayer()

        super.init(frame:CGRect.zero)

        self.layer.addSublayer(self.horizontalBarLayer)
        self.layer.addSublayer(self.progressLayer)
    }

    internal func updateSubviews() {
        AssertIsOnMainThread()

        self.horizontalBarLayer.frame = self.bounds
        self.progressLayer.frame = self.bounds

        updateContent()
    }

    internal func updateContent() {
        AssertIsOnMainThread()

        let horizontalBarPath = UIBezierPath()
        let horizontalBarHeightFraction = CGFloat(0.25)
        let horizontalBarHeight = bounds.size.height * horizontalBarHeightFraction
        horizontalBarPath.append(UIBezierPath(rect: CGRect(x: 0, y:(bounds.size.height - horizontalBarHeight) * 0.5, width:bounds.size.width, height:horizontalBarHeight)))
        horizontalBarLayer.path = horizontalBarPath.cgPath
        horizontalBarLayer.fillColor = horizontalBarColor.cgColor

        let progressHeight = bounds.self.height
        let progressWidth = progressHeight * 0.15
        let progressX = (bounds.self.width - progressWidth) * max(0.0, min(1.0, progress))
        let progressBounds = CGRect(x:progressX, y:0, width:progressWidth, height:progressHeight)
        let progressCornerRadius = progressWidth * 0.5
        let progressPath = UIBezierPath()
        progressPath.append(UIBezierPath(roundedRect: progressBounds, cornerRadius: progressCornerRadius))
        progressLayer.path = progressPath.cgPath
        progressLayer.fillColor = progressColor.cgColor
    }
}
