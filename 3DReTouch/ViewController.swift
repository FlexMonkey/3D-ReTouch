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
        
        let white = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        let black = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        gradient.setValue(white, forKey: "inputColor0")
        gradient.setValue(black, forKey: "inputColor1")
        gradient.setValue(CIVector(x: 100, y: 100), forKey:  kCIInputCenterKey)
        gradient.setValue(50, forKey: "inputRadius0")
        gradient.setValue(100, forKey: "inputRadius1")
        
        noir.setValue(ciSunflower, forKey: kCIInputImageKey)
        
        blendWithMask.setValue(ciSunflower, forKey: kCIInputBackgroundImageKey)
        blendWithMask.setValue(noir.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
        blendWithMask.setValue(gradient.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputMaskImageKey)
        
        //----
        
        view.addSubview(imageView)
        imageView.frame = CGRect(origin: CGPointZero, size: CGSize(width: 640, height: 640))
        
        imageView.image = UIImage(CIImage: blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
        
        // imageView.image = UIImage(CIImage: imageAccumulator.image())
    }

    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first,
            event = event,
            coalescedTouches = event.coalescedTouchesForTouch(touch)
            where imageView.frame.contains(touches.first!.locationInView(imageView)) else
        {
            return
        }
        
        gradientAccumulator.clear()
        
        for coalescedTouch in coalescedTouches
        {
            let location = coalescedTouch.locationInView(imageView)
            
            gradient.setValue(CIVector(x: location.x, y: 640 - location.y), forKey: kCIInputCenterKey)
            
            gradientCompositeFilter.setValue(gradientAccumulator.image(), forKey: kCIInputBackgroundImageKey)
            gradientCompositeFilter.setValue(gradient.valueForKey(kCIOutputImageKey), forKey: kCIInputImageKey)

            gradientAccumulator.setImage(gradientCompositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        }
        
        imageView.image = UIImage(CIImage: gradientAccumulator.image())
    }
    
    
}
