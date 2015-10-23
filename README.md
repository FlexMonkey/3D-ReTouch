# 3D-ReTouch
Experimental Retouching App using 3D Touch

####_Companion Project to http://flexmonkey.blogspot.co.uk/2015/10/3d-retouch-experimental-retouching-app.html_

Here's the latest in my series of experiments exploring the possibilities offered by 3D Touch. My 3DReTouch app allows the user to select one of a handful of image adjustments and apply that adjustment locally with an intensity based on the force of their touch. A quick shake of their iPhone removes all their adjustments and lets them start over.

Much like ForceSketch, this app uses `CIImageAccumulator` and also makes use of Core Image's mask blend to selectively blend a filter over an image using a radial gradient centred on the user's touch.

##The Basics

The preset filters are constants of type `Filter` and, along with an instance of their relevant Core Image filter, they contain details of which of their parameters are dependent on the touch force. For example, the sharpen filter is a Sharpen Luminance filter and its input sharpness varies depending on force:

    Filter(name: "Sharpen", ciFilter: CIFilter(name: "CISharpenLuminance")!,
        variableParameterName: kCIInputSharpnessKey,
        variableParameterDefault: 0,
        variableParameterMultiplier: 0.25)

The array of filters acts as a data provider for a `UIPickerView`. When the picker view changes, I set `currentFilter` to the selected item for use later:

    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int)
    {
        currentFilter = filters[row]
    }

The image filtering happens in a background thread by picking pending items from a first-in-first-out queue, so I use a `CADisplayLink` to schedule that task with each frame update. 

##Touch Handling

With both the touchesBegan and touchesMoved touch handlers, I want to create a `PendingUpdate` struct containing the touch's force, position and current filter and add that to my queue. This is done inside `applyFilterFromTouches()`  and first of all a guard ensures we have a touch and it's in the image boundary:

    guard let touch = touches.first
        where imageView.frame.contains(touches.first!.locationInView(imageView)) else
    {
        return
    }

Next, I normalise the touch force or create a default for non-3D Touch devices:

    let normalisedForce = traitCollection.forceTouchCapability == UIForceTouchCapability.Available ?
        touch.force / touch.maximumPossibleForce :

        CGFloat(0.5)

Then using the scale of the image, I can calculate the touch position in the actual image, create my `PendingUpdate` object and append it to the queue:

    let imageScale = imageViewSide / fullResImageSide
    let location = touch.locationInView(imageView)
        
    let pendingUpdate = PendingUpdate(center: CIVector(x: location.x / imageScale, y: (imageViewSide - location.y) / imageScale),
        radius: 80,
        force: normalisedForce,
        filter: currentFilter)
    
    pendingUpdatesToApply.append(pendingUpdate)

##Applying the Filter

My `update()` function is invoked by the `CADisplayLink`:

    let displayLink = CADisplayLink(target: self, selector: Selector("update"))
    displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)

Using `guard` (again!), I ensure there's actually a pending update to process:

    guard pendingUpdatesToApply.count > 0 else
    {
        return
    }

...and if there is, I remove it and assign to pendingUpdate:

    let pendingUpdate = pendingUpdatesToApply.removeFirst()

The remainder of the method happens inside dispatch_async and is split into several parts. First of all, I update the position of my radial gradient based on the touch location:

    let gradientFilter = CIFilter(name: "CIGaussianGradient",
        withInputParameters: [
            "inputColor1": CIColor(red: 0, green: 0, blue: 0, alpha: 0),
            "inputColor0": CIColor(red: 1, green: 1, blue: 1, alpha: 1)])!

    self.gradientFilter.setValue(pendingUpdate.center,
        forKey: kCIInputCenterKey)

Then I set the Core Image filter of the `pendingUpdate` object's parameters. It needs an input image which I take from the image accumulator and it needs its force dependant parameter (`variableParameterName`) updating based on the touch's force:

    pendingUpdate.filter.ciFilter.setValue(self.imageAccumulator.image(), forKey: kCIInputImageKey)
    
    pendingUpdate.filter.ciFilter.setValue(
        pendingUpdate.filter.variableParameterDefault + (pendingUpdate.force * pendingUpdate.filter.variableParameterMultiplier),
        forKey: pendingUpdate.filter.variableParameterName)

With these, I can populate my Blend With Mark filter's parameters. It will use the gradient as a mask to overlay the newly filtered image over the existing image from the accumulator only where the user has touched:

So, it needs the base image, the filtered image and the gradient as a mask:

    let blendWithMask = CIFilter(name: "CIBlendWithMask")!


    self.blendWithMask.setValue(self.imageAccumulator.image(), forKey: kCIInputBackgroundImageKey)
    
    self.blendWithMask.setValue(pendingUpdate.filter.ciFilter.valueForKey(kCIOutputImageKey) as! CIImage,
        forKey: kCIInputImageKey)
    
    self.blendWithMask.setValue(self.gradientFilter.valueForKey(kCIOutputImageKey) as! CIImage,
        forKey: kCIInputMaskImageKey)

Finally, I can take the output of that blend, reassign it the the accumulator and create a `UIImage` to display on screen:

    self.imageAccumulator.setImage(self.blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)

    let finalImage = UIImage(CIImage: self.blendWithMask.valueForKey(kCIOutputImageKey) as! CIImage)

Updating my image view needs to happen in the main thread to ensure the screen is updated:

    dispatch_async(dispatch_get_main_queue())
    {
        self.imageView.image = finalImage
    }

##In Conclusion

As a tech-demo, 3D ReTouch illustrates how Apple's 3D Touch can be used to effectively control the strength of a Core Image filter. However, I suspect the iPhone isn't an ideal device for this - my chubby fingers block out what's happening on screen. The iPad Pro, with its Pencil, would be a far more suitable device. Alternatively, simulating a separate track pad (similar to the deep press on the iOS keyboard) may work better.

As always, the source code for this can be found in my GitHub repository here. Enjoy!
