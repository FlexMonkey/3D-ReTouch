//
//  ViewController.swift
//  3DReTouch
//
//  Created by Simon Gladman on 15/10/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import UIKit

let fullResImageSide: CGFloat = 640

let filters = [
    Filter(name: "Sharpen", ciFilter: CIFilter(name: "CISharpenLuminance")!,
        variableParameterName: kCIInputSharpnessKey,
        variableParameterDefault: 0,
        variableParameterMultiplier: 0.25),
    
    Filter(name: "Darken", ciFilter: CIFilter(name: "CIExposureAdjust")!,
        variableParameterName: kCIInputEVKey,
        variableParameterDefault: 0,
        variableParameterMultiplier: -0.2),
    
    Filter(name: "Lighten", ciFilter: CIFilter(name: "CIExposureAdjust")!,
        variableParameterName: kCIInputEVKey,
        variableParameterDefault: 0,
        variableParameterMultiplier: 0.2),
    
    Filter(name: "Increase Contrast", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputContrastKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: 0.1),
    
    Filter(name: "Decrease Contrast", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputContrastKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: -0.1),
    
    Filter(name: "Increase Saturation", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputSaturationKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: 0.15),
    
    Filter(name: "Decrease Saturation", ciFilter: CIFilter(name: "CIColorControls")!,
        variableParameterName: kCIInputSaturationKey,
        variableParameterDefault: 1,
        variableParameterMultiplier: -0.15)]

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
    typealias PendingUpdate = (center: CIVector, radius: CGFloat, force: CGFloat, filter: Filter)
    
    let backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    
    let gradientFilter = CIFilter(name: "CIGaussianGradient",
        withInputParameters: [
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1)])!
   
    let blendWithMask = CIFilter(name: "CIBlendWithMask")!
    var currentFilter = filters.first!
    
    let imageAccumulator = CIImageAccumulator(
        extent: CGRect(origin: CGPointZero,
        size: CGSize(width: fullResImageSide, height: fullResImageSide)),
        format: kCIFormatARGB8)
    
    let imageView = UIImageView()
    let picker = UIPickerView()
    let progressView = UIProgressView()
    
    let sunflowerImage = CIImage(image: UIImage(named: "sunflower.jpg")!)!
 
    var pendingUpdatesToApply = [PendingUpdate]()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
  
        imageAccumulator.setImage(sunflowerImage)

        imageView.image = UIImage(CIImage: imageAccumulator.image())
        imageView.contentScaleFactor = 0.25
        imageView.contentMode = UIViewContentMode.ScaleAspectFit

        view.addSubview(imageView)
        view.addSubview(picker)
        view.addSubview(progressView)
        
        picker.delegate = self
        picker.dataSource = self
        
        let displayLink = CADisplayLink(target: self, selector: Selector("update"))
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        applyFilterFromTouches(touches)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        applyFilterFromTouches(touches)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        progressView.progress = 0
    }
    
    override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?)
    {
        if motion == UIEventSubtype.MotionShake
        {
            imageAccumulator.setImage(sunflowerImage)
            imageView.image = UIImage(CIImage: imageAccumulator.image())
        }
    }

    func applyFilterFromTouches(touches: Set<UITouch>)
    {
        guard let touch = touches.first
            where imageView.frame.contains(touches.first!.locationInView(imageView)) else
        {
            return
        }

        let imageScale = imageViewSide / fullResImageSide
        
        let location = touch.locationInView(imageView)
        let normalisedForce = traitCollection.forceTouchCapability == UIForceTouchCapability.Available ?
            touch.force / touch.maximumPossibleForce :
            CGFloat(0.5)
        
        progressView.progress = Float(normalisedForce)

        let pendingUpdate = PendingUpdate(center: CIVector(x: location.x / imageScale, y: (imageViewSide - location.y) / imageScale),
            radius: 80,
            force: normalisedForce,
            filter: currentFilter)
        
        pendingUpdatesToApply.append(pendingUpdate)
    }

    func update()
    {
        guard pendingUpdatesToApply.count > 0 else
        {
            return
        }
        
        let pendingUpdate = pendingUpdatesToApply.removeFirst()

        dispatch_async(backgroundQueue)
        {
            self.gradientFilter.setValue(pendingUpdate.center,
                forKey: kCIInputCenterKey)
            self.gradientFilter.setValue(pendingUpdate.radius, forKey: "inputRadius")

            pendingUpdate.filter.ciFilter.setValue(self.imageAccumulator.image(), forKey: kCIInputImageKey)
            pendingUpdate.filter.ciFilter.setValue(
                pendingUpdate.filter.variableParameterDefault + (pendingUpdate.force * pendingUpdate.filter.variableParameterMultiplier),
                forKey: pendingUpdate.filter.variableParameterName)
            
            self.blendWithMask.setValue(self.imageAccumulator.image(), forKey: kCIInputBackgroundImageKey)
            self.blendWithMask.setValue(pendingUpdate.filter.ciFilter.valueForKey(kCIOutputImageKey) as! CIImage,
                forKey: kCIInputImageKey)
            self.blendWithMask.setValue(self.gradientFilter.valueForKey(kCIOutputImageKey) as! CIImage, forKey: kCIInputMaskImageKey)
            
            self.imageAccumulator.setImage(self.blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)

            let finalImage = UIImage(CIImage: self.blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)
            
            dispatch_async(dispatch_get_main_queue())
            {
                self.imageView.image = finalImage
            }
            
        }
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
        currentFilter = filters[row]
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
