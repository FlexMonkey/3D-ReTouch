//
//  ViewController.swift
//  3DReTouch
//
//  Created by Simon Gladman on 15/10/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

let fullResImageSide: CGFloat = 640

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource
{
    let sunflower = UIImage(named: "sunflower.jpg")!
    
    let gradient = CIFilter(name: "CIRadialGradient")!
    let blendWithMask = CIFilter(name: "CIBlendWithMask")!
    var filter = CIFilter(name: "CICrystallize")!

    let gradientCompositeFilter = CIFilter(name: "CISourceOverCompositing")!
    
    let gradientAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero, size: CGSize(width: fullResImageSide, height: fullResImageSide)),
        format: kCIFormatARGB8)
    
    let imageAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero, size: CGSize(width: fullResImageSide, height: fullResImageSide)),
        format: kCIFormatARGB8)
    
    let imageView = UIImageView()
    let picker = UIPickerView()
    
    let filters = [
        "CICrystallize",
        "CICMYKHalftone",
        "CIGaussianBlur",
        "CIUnsharpMask",
        "CIColorPosterize"]
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let ciSunflower = CIImage(image: sunflower)!
        
        imageAccumulator.setImage(ciSunflower)

        imageView.image = UIImage(CIImage: imageAccumulator.image())
        imageView.contentScaleFactor = 0.25
        imageView.contentMode = UIViewContentMode.ScaleAspectFit

        view.addSubview(imageView)
        view.addSubview(picker)
        
        picker.delegate = self
        picker.dataSource = self
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
    
    func createGradientFromTouches(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first,
            event = event,
            coalescedTouches = event.coalescedTouchesForTouch(touch)
            where imageView.frame.contains(touches.first!.locationInView(imageView)) else
        {
            return
        }

        let imageScale = imageViewSide / fullResImageSide;
        
        for coalescedTouch in coalescedTouches
        {
            let location = coalescedTouch.locationInView(imageView)
            
            gradient.setValue(CIVector(x: location.x / imageScale, y: (imageViewSide - location.y) / imageScale), forKey: kCIInputCenterKey)
            
            let white = CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.001 + ((coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 0.05))
            let black = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            gradient.setValue(white, forKey: "inputColor0")
            gradient.setValue(black, forKey: "inputColor1")
            
            gradient.setValue(1, forKey: "inputRadius0")
            gradient.setValue(1 + ((coalescedTouch.force / coalescedTouch.maximumPossibleForce) * 100), forKey: "inputRadius1")
            
            gradientCompositeFilter.setValue(gradientAccumulator.image(), forKey: kCIInputBackgroundImageKey)
            gradientCompositeFilter.setValue(gradient.valueForKey(kCIOutputImageKey), forKey: kCIInputImageKey)
            
            gradientAccumulator.setImage(gradientCompositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        }
        
        filter.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
        
        blendWithMask.setValue(imageAccumulator.image(), forKey: kCIInputBackgroundImageKey)
        blendWithMask.setValue(filter.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputImageKey)
        blendWithMask.setValue(gradientAccumulator.image(), forKey: kCIInputMaskImageKey)
        
        imageAccumulator.setImage(blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
        imageView.image = UIImage(CIImage: blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(x: 0, y: topLayoutGuide.length, width: imageViewSide, height: imageViewSide)
        
        if view.frame.width > view.frame.height
        {
            picker.frame = CGRect(x: imageViewSide, y: topLayoutGuide.length, width: view.frame.width - imageViewSide, height: imageViewSide)
        }
        else
        {
            picker.frame = CGRect(x: 0, y: topLayoutGuide.length + imageViewSide, width: view.frame.width, height: view.frame.height - imageViewSide - topLayoutGuide.length)
        }
    }
    
    var imageViewSide: CGFloat
    {
        return min(view.frame.width, view.frame.height - topLayoutGuide.length)
    }
    
    //-----
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        filter = CIFilter(name: filters[row])!
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        return filters[row]
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int
    {
        return filters.count
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int
    {
        return 1; 
    }
}
