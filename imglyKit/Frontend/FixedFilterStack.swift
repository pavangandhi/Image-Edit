//
//  FixedFilterStack.swift
//  imglyKit
//
//  Created by Sascha Schwabbauer on 08/04/15.
//  Copyright (c) 2015 9elements GmbH. All rights reserved.
//

import UIKit
import CoreImage

/**
*   This class represents the filterstack that is used when using the UI.
*   It represents a chain of filters that will be applied to the taken image.
*   That way we make sure the order of filters stays the same, and we don't need to take
*   care about creating the single filters.
*/
@objc(IMGLYFixedFilterStack) public class FixedFilterStack: NSObject {

    // MARK: - Properties

    public var enhancementFilter: EnhancementFilter = {
        let filter = InstanceFactory.enhancementFilter()
        filter.enabled = false
        filter.storeEnhancedImage = true
        return filter
        }()

    public var orientationCropFilter = InstanceFactory.orientationCropFilter()
    public var effectFilter = InstanceFactory.effectFilterWithType(FilterType.None)
    public var brightnessFilter = InstanceFactory.colorAdjustmentFilter()
    public var tiltShiftFilter = InstanceFactory.tiltShiftFilter()
    public var spriteFilters = [Filter]()

    public var activeFilters: [Filter] {
        setCropRectForStickerFilters()
        setCropRectForTextFilters()
        var activeFilters: [Filter] = [enhancementFilter, orientationCropFilter, tiltShiftFilter, effectFilter, brightnessFilter]
        activeFilters += spriteFilters
        return activeFilters
    }

    private func setCropRectForStickerFilters () {
        for stickerFilter in spriteFilters where stickerFilter is StickerFilter {
            // swiftlint:disable force_cast
            (stickerFilter as! StickerFilter).cropRect = orientationCropFilter.cropRect
            // swiftlint:enable force_fast
        }
    }

    private func setCropRectForTextFilters () {
        for textFilter in spriteFilters where textFilter is TextFilter {
            // swiftlint:disable force_cast
            (textFilter as! TextFilter).cropRect = orientationCropFilter.cropRect
            // swiftlint:enable force_fast
        }
    }

    public func rotateStickersRight () {
        for filter in self.activeFilters {
            if let stickerFilter = filter as? StickerFilter {
                stickerFilter.rotateRight()
            }
        }
    }

    public func rotateStickersLeft () {
        for filter in self.activeFilters {
            if let stickerFilter = filter as? StickerFilter {
                stickerFilter.rotateLeft()
            }
        }
    }

    public func rotateTextRight () {
        rotateText(CGFloat(M_PI_2), negateX: true, negateY: false)
    }

    public func rotateTextLeft () {
        rotateText(CGFloat(-M_PI_2), negateX: false, negateY: true)
    }

    private func rotateText (angle: CGFloat, negateX: Bool, negateY: Bool) {
        let xFactor: CGFloat = negateX ? -1.0 : 1.0
        let yFactor: CGFloat = negateY ? -1.0 : 1.0
        for filter in self.activeFilters {
            if let textFilter = filter as? TextFilter, image = textFilter.inputImage {
                textFilter.transform = CGAffineTransformRotate(textFilter.transform, angle)
                textFilter.center.x -= 0.5
                textFilter.center.y -= 0.5
                let ratio = image.extent.size.height / image.extent.size.width
                textFilter.initialFontSize *= ratio
                let center = textFilter.center
                textFilter.center.x = xFactor * center.y
                textFilter.center.y = yFactor * center.x
                textFilter.center.x += 0.5
                textFilter.center.y += 0.5
            }
        }
    }

    public func flipStickersHorizontal () {
        for filter in self.activeFilters {
            if let stickerFilter = filter as? StickerFilter {
                stickerFilter.flipStickersHorizontal()
            }
        }
    }

    public func flipStickersVertical () {
        for filter in self.activeFilters {
            if let stickerFilter = filter as? StickerFilter {
                stickerFilter.flipStickersVertical()
            }
        }
    }

    public func flipTextHorizontal () {
        flipText(true)
    }

    public func flipTextVertical () {
        flipText(false)
    }

    private func flipText(horizontal: Bool) {
        for filter in self.activeFilters {
            if let stickerFilter = filter as? TextFilter {
                stickerFilter.center.x -= 0.5
                stickerFilter.center.y -= 0.5
                let center = stickerFilter.center
                if horizontal {
                    flipRotationHorizontal(stickerFilter)
                    stickerFilter.center.x = -center.x
                } else {
                    flipRotationVertical(stickerFilter)
                    stickerFilter.center.y = -center.y
                }
                stickerFilter.center.x += 0.5
                stickerFilter.center.y += 0.5
            }
        }
    }

    private func flipRotationHorizontal(textFilter: TextFilter) {
        flipRotation(textFilter, axisAngle: CGFloat(M_PI))
    }

    private func flipRotationVertical(textFilter: TextFilter) {
        flipRotation(textFilter, axisAngle: CGFloat(M_PI_2))
    }

    private func flipRotation(textFilter: TextFilter, axisAngle: CGFloat) {
        var angle = atan2(textFilter.transform.b, textFilter.transform.a)
        let twoPI = CGFloat(M_PI * 2.0)
        // normalize angle
        while angle >= twoPI {
            angle -= twoPI
        }

        while angle < 0 {
            angle += twoPI
        }

        let delta = axisAngle - angle
        textFilter.transform = CGAffineTransformRotate(textFilter.transform, delta * 2.0)
    }

    // MARK: - Initializers
    required override public init () {
        super.init()
    }

}

extension FixedFilterStack: NSCopying {
    public func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = self.dynamicType.init()
        // swiftlint:disable force_cast
        copy.enhancementFilter = enhancementFilter.copyWithZone(zone) as! EnhancementFilter
        copy.orientationCropFilter = orientationCropFilter.copyWithZone(zone) as! OrientationCropFilter
        copy.effectFilter = effectFilter.copyWithZone(zone) as! EffectFilter
        copy.brightnessFilter = brightnessFilter.copyWithZone(zone) as! ContrastBrightnessSaturationFilter
        copy.tiltShiftFilter = tiltShiftFilter.copyWithZone(zone) as! TiltshiftFilter
        copy.spriteFilters = NSArray(array: spriteFilters, copyItems: true) as! [Filter]
        // swiftlint:enable force_cast
        return copy
    }
}
