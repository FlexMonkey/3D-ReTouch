//
//  ViewController.swift
//  3DReTouch
//
//  Created by Simon Gladman on 15/10/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit

let fullResImageSide: CGFloat = 640
let black = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
let white = CIColor(red: 1, green: 1, blue: 1, alpha: 1)

let filters = [
    Filter(name: "Darken", ciFilter: CIFilter(name: "CIExposureAdjust")!,
        variableParameterName: kCIInputEVKey,
        variableParameterDefault: 0,
        variableParameterMultiplier: -0.05),
    
    Filter(name: "Lighten", ciFilter: CIFilter(name: "CIExposureAdjust")!,
        variableParameterName: kCIInputEVKey,
        variableParameterDefault: 0,
        variableParameterMultiplier: 0.05),
    
    Filter(name: "Increase Contrast", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputContrastKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: 0.05),
    
    Filter(name: "Decrease Contrast", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputContrastKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: -0.05),
    
    Filter(name: "Increase Saturation", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputSaturationKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: 0.1),
    
    Filter(name: "Decrease Saturation", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputSaturationKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: -0.1)
    ]

struct Filter
{
    let name:String
    let ciFilter: CIFilter
    let variableParameterName: String
    let variableParameterDefault: CGFloat
    let variableParameterMultiplier: CGFloat
}

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource
{
    let gradient = CIFilter(name: "CIGaussianGradient", withInputParameters: ["inputColor1": black, "inputColor0": white])!
    let gradientBlur = CIFilter(name: "CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: 10])!
    let blendWithMask = CIFilter(name: "CIBlendWithMask")!
    var filter = filters.first!

    let gradientCompositeFilter = CIFilter(name: "CISourceOverCompositing")!
    
    let gradientAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero,
        size: CGSize(width: fullResImageSide, height: fullResImageSide)),
        format: kCIFormatARGB8)
    
    let imageAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero,
        size: CGSize(width: fullResImageSide, height: fullResImageSide)),
        format: kCIFormatARGB8)
    
    let imageView = UIImageView()
    let picker = UIPickerView()
    let progressView = UIProgressView()
    
    let ciSunflower = CIImage(image: UIImage(named: "sunflower.jpg")!)!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
  
        imageAccumulator.setImage(ciSunflower)

        imageView.image = UIImage(CIImage: imageAccumulator.image())
        imageView.contentScaleFactor = 0.25
        imageView.contentMode = UIViewContentMode.ScaleAspectFit

        view.addSubview(imageView)
        view.addSubview(picker)
        view.addSubview(progressView)
        
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
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        progressView.progress = 0
    }
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?)
    {
        if motion == UIEventSubtype.MotionShake
        {
            imageAccumulator.setImage(ciSunflower)
            imageView.image = UIImage(CIImage: imageAccumulator.image())
        }
    }
    
    func createGradientFromTouches(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        guard let touch = touches.first
            where imageView.frame.contains(touches.first!.locationInView(imageView)) else
        {
            return
        }

        let imageScale = imageViewSide / fullResImageSide;
        
        let location = touch.locationInView(imageView)
        let normalisedForce = touch.force / touch.maximumPossibleForce
        
        progressView.progress = Float(normalisedForce)
        
        gradient.setValue(CIVector(x: location.x / imageScale, y: (imageViewSide - location.y) / imageScale),
            forKey: kCIInputCenterKey)
        gradient.setValue(10 + (normalisedForce * 20), forKey: "inputRadius")
        
        gradientCompositeFilter.setValue(gradientAccumulator.image(), forKey: kCIInputBackgroundImageKey)
        gradientCompositeFilter.setValue(gradient.valueForKey(kCIOutputImageKey), forKey: kCIInputImageKey)
        
        gradientAccumulator.setImage(gradientCompositeFilter.valueForKey(kCIOutputImageKey) as! CIImage)
        
        gradientBlur.setValue(gradientAccumulator.image(), forKey: kCIInputImageKey)
        gradientAccumulator.setImage(gradientBlur.valueForKey(kCIOutputImageKey) as! CIImage)
        
        filter.ciFilter.setValue(imageAccumulator.image(), forKey: kCIInputImageKey)
        filter.ciFilter.setValue(filter.variableParameterDefault + (normalisedForce * filter.variableParameterMultiplier),
            forKey: filter.variableParameterName)
        
        blendWithMask.setValue(imageAccumulator.image(), forKey: kCIInputBackgroundImageKey)
        blendWithMask.setValue(filter.ciFilter.valueForKey(kCIOutputImageKey) as! CIImage,
            forKey: kCIInputImageKey)
        blendWithMask.setValue(gradientAccumulator.image(), forKey: kCIInputMaskImageKey)
        
        imageAccumulator.setImage(blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
        imageView.image = UIImage(CIImage: blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = CGRect(x: 0,
            y: topLayoutGuide.length,
            width: imageViewSide,
            height: imageViewSide)
        
        progressView.frame = CGRect(x: 0,
            y: topLayoutGuide.length,
            width: view.frame.width,
            height: progressView.intrinsicContentSize().height)
        
        if view.frame.width > view.frame.height
        {
            picker.frame = CGRect(x: imageViewSide,
                y: topLayoutGuide.length,
                width: view.frame.width - imageViewSide,
                height: imageViewSide)
        }
        else
        {
            picker.frame = CGRect(x: 0,
                y: topLayoutGuide.length + imageViewSide,
                width: view.frame.width,
                height: view.frame.height - imageViewSide - topLayoutGuide.length)
        }
    }
    
    var imageViewSide: CGFloat
    {
        return min(view.frame.width, view.frame.height - topLayoutGuide.length)
    }
    
    //-----
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        filter = filters[row]
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        return filters[row].name
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
