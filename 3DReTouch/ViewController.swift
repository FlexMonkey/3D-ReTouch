//
//  ViewController.swift
//  3DReTouch
//
//  Created by Simon Gladman on 15/10/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{
    let sunflower = UIImage(named: "sunflower.jpg")!  // 640 x 640
    
    let gradient = CIFilter(name: "CIRadialGradient")! // inputColor0  inputColor1 inputCenter inputRadius
    let blendWithMask = CIFilter(name: "CIBlendWithMask")! // inputBackgroundImage  inputMaskImage
    let noir = CIFilter(name: "CIPhotoEffectNoir")!

    let gradientCompositeFilter = CIFilter(name: "CISourceOverCompositing")!
    
    let gradientAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero, size: CGSize(width: 640, height: 640)),
        format: kCIFormatARGB8)
    
    let imageAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero, size: CGSize(width: 640, height: 640)),
        format: kCIFormatARGB8)
    
    let imageView = UIImageView()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        view.backgroundColor = UIColor.blackColor()
        
        let ciSunflower = CIImage(image: sunflower)!
        
        imageAccumulator.setImage(ciSunflower)

        imageView.image = UIImage(CIImage: imageAccumulator.image())
        
        view.addSubview(imageView)
        imageView.frame = CGRect(origin: CGPointZero, size: CGSize(width: 640, height: 640))
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        gradientAccumulator.setImage(CIImage())

        createGradientFromTouches(touches, withEvent: event)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        createGradientFromTouches(touches, withEvent: event)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        print("end")
    }
    
    func createGradientFromTouches(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first,
            event = event,
            coalescedTouches = event.coalescedTouchesForTouch(touch)
            where imageView.frame.contains(touches.first!.locationInView(imageView)) else
        {
            return
        }
        
        for coalescedTouch in coalescedTouches
        {
            let location = coalescedTouch.locationInView(imageView)
            
            gradient.setValue(CIVector(x: location.x, y: 640 - location.y), forKey: kCIInputCenterKey)
            
            let white = CIColor(red: 1, green: 1, blue: 1, alpha: 0.05 + ((coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 0.25))
            let black = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            gradient.setValue(white, forKey: "inputColor0")
            gradient.setValue(black, forKey: "inputColor1")
            
            gradient.setValue(1, forKey: "inputRadius0")
            gradient.setValue(20 + ((coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 40), forKey: "inputRadius1")
            
            gradientCompositeFilter.setValue(gradientAccumulator.image(), forKey: kCIInputBackgroundImageKey)
            gradientCompositeFilter.setValue(gradient.valueForKey(kCIOutputImageKey), forKey: kCIInputImageKey)
            
            gradientAccumulator.setImage(gradientCompositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        }
        
        noir.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
        
        blendWithMask.setValue(imageAccumulator.image(), forKey: kCIInputBackgroundImageKey)
        blendWithMask.setValue(noir.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
        blendWithMask.setValue(gradientAccumulator.image(), forKey: kCIInputMaskImageKey)
        
        imageAccumulator.setImage(blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
        imageView.image = UIImage(CIImage: blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
    }
    
}
