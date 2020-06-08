//
//  MasterController.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/7/20.
//

import Foundation
import GameController

final class MasterController: ObservableObject
{
    @Published var timelapse: Bool = true
    @Published var numTimelapseFrames: Int = 150 // e.g. five seconds at 30fps
    @Published var releaseBetweenFrames: Bool = false
    @Published var steppers:[StepperMotor] = [
        StepperMotor(code:.slider),
        StepperMotor(code:.pan),
        StepperMotor(code:.tilt),
        StepperMotor(code:.focus)
    ]
    @Published var keyframes:[Keyframe] = []
    
    @Published var running = false
    @Published var stop = false
    
    var controllers:[GCController] = []
    var selectedController:GCExtendedGamepad?
    
    func findAttachedControllers() {
        GCController.startWirelessControllerDiscovery(completionHandler: {
            self.controllers = GCController.controllers()
            for controller in self.controllers {
                if controller.extendedGamepad != nil {
                    self.selectedController = controller.extendedGamepad
                    self.selectedController?.valueChangedHandler = self.controllerChanged
                    break // Let's select the first one, for my purposes there are never more...
                }
            }
        })
    }
    
    func controllerChanged(gamepad:GCExtendedGamepad, element:GCControllerElement) {
        // The control mapping is:
        // Left joystick:
        //   Left/right: Pan
        //   Up/down: Tilt
        // Right joystick:
        //   Left/right: Slide
        //   Up/down: Ignored
        // L1/L2 trigger: Focus in and out
        // X: Take photo
        // Y: Zero
        
        // Figure out which element it was...
        if element == gamepad.leftThumbstick {
            print ("Left thumbstick")
        } else if element == gamepad.rightThumbstick {
            print ("Right thumbstick")
        } else if element == gamepad.leftTrigger {
            print ("Left trigger")
        } else if element == gamepad.rightTrigger {
            print ("Right trigger")
        } else if element == gamepad.buttonX {
            print ("X")
        } else if element == gamepad.buttonY {
            print ("Y")
        }
    }
    
    func returnToZero () {
        running = true
        stop = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            self.returnToZeroDispatch()
            DispatchQueue.main.async { [weak self] in
                self?.runComplete()
            }
        }
    }
    
    func returnToZeroDispatch() {
        
        SliderSerialInterface.shared.runCoordinatedMotionToPosition(slider:0,pan:0,tilt:0,focus:0)
        
        // Now we have to wait for this to actually happen...
        var working = true;
        while (working) {
            sleep(1)
            if SliderSerialInterface.shared.sliderState == .holding &&
                SliderSerialInterface.shared.panState == .holding &&
                SliderSerialInterface.shared.tiltState == .holding &&
                SliderSerialInterface.shared.focusState == .holding {
                working = false;
            }
        }

    }

    func run () {
        running = true
        stop = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            self.runDispatch()
            DispatchQueue.main.async { [weak self] in
                self?.runComplete()
            }
        }
    }

    fileprivate func runDispatch() {
        returnToZeroDispatch(); //Blocks until it's done, or the motion is cancelled by the user
        
        if SliderSerialInterface.shared.sliderPosition != 0 ||
           SliderSerialInterface.shared.panPosition != 0 ||
           SliderSerialInterface.shared.tiltPosition != 0 ||
           SliderSerialInterface.shared.focusPosition != 0 ||
           stop {
            return // Because the user must have cancelled the motion.
        }
        
        if timelapse {
            runTimelapse()
        } else {
            runSingleMotion()
        }
    }
    
    fileprivate func runTimelapse() {
        if keyframes.isEmpty {
            print ("No keyframes set")
            return
        }
        if keyframes.first!.time <= 0.0 {
            print ("All keyframes must have times greater than zero. The Zero keyframe is implied, and starts at the configured stepper Zero.")
            return
        }
        
        // Construct a sequence of keyframes in between whatever frames are provided
        var timelapseFrames:[Keyframe] = []
        let totalTime = keyframes.last!.time
        let deltaT = totalTime / Float(numTimelapseFrames)
        
        // Sanity checks
        if deltaT < 3.0 {
            print ("It is unlikely that the camera will be in position in time to take this number of keyframes. Bailing...")
            cancel()
            return
        }
        
        if deltaT > 14.5 * 60 { // Technically it's a 15 minute timer, but let's add some safety margin
            print ("The camera will stop looking for IR signals before the next keyframe is triggered. Bailing...")
            cancel()
            return
        }
        
        var t:Float = 0.0
        var previousFrame = Keyframe(id: 0, time: 0.0, sliderPosition: 0, panPosition: 0, tiltPosition: 0, focusPosition: 0)
        for keyframe in keyframes {
            // For every keyframe, figure out what fraction of the total time it represents
            let majorDeltaT = keyframe.time - t
            let keyframeFraction = majorDeltaT / totalTime
            let numberOfMinorFrames = Int(round(keyframeFraction * Float(numTimelapseFrames)))
            
            // Calculate the per-step deltas: calculate them as floats, we will round them during the next step
            let deltaSlider = Float(keyframe.sliderPosition! - previousFrame.sliderPosition!) / Float(numberOfMinorFrames)
            let deltaPan = Float(keyframe.panPosition! - previousFrame.panPosition!) / Float(numberOfMinorFrames)
            let deltaTilt = Float(keyframe.tiltPosition! - previousFrame.tiltPosition!) / Float(numberOfMinorFrames)
            let deltaFocus = Float(keyframe.focusPosition! - previousFrame.focusPosition!) / Float(numberOfMinorFrames)
            
            var subframe:Float = 0
            while t < keyframe.time {
                timelapseFrames.append(Keyframe(id: timelapseFrames.count,
                                                time: t,
                                                sliderPosition: previousFrame.sliderPosition!+Int32(round(subframe*deltaSlider)),
                                                panPosition: previousFrame.panPosition!+Int32(round(subframe*deltaPan)),
                                                tiltPosition: previousFrame.tiltPosition!+Int32(round(subframe*deltaTilt)),
                                                focusPosition: previousFrame.focusPosition!+Int32(round(subframe*deltaFocus))))
                subframe += 1.0
                t += deltaT
            }
            previousFrame = timelapseFrames.last!
        }
        timelapseFrames.append(keyframes.last!)
        
        // Return to the zero point
        returnToZeroDispatch()
        
        let startTime = Date()
        var frameNumber = 0
        for keyframe in timelapseFrames {
            if stop {
                return
            }
            SliderSerialInterface.shared.takePhoto()
            runToKeyframe(keyframe: keyframe) // This blocks until the motion is complete...
            if releaseBetweenFrames {
                SliderSerialInterface.shared.releaseSteppers()
            }
            frameNumber += 1
            // Spin our wheels waiting for either a cancel or the next frame time
            while Date() < Date(timeInterval: TimeInterval(Float(frameNumber)*deltaT), since: startTime)  {
                if stop {
                    return
                }
            }
        }
        SliderSerialInterface.shared.takePhoto()
        
        // And we're done!
    }
    
    fileprivate func runSingleMotion() {
        for keyframe in keyframes {
            runToKeyframe(keyframe: keyframe) // Blocks until motion is completed or cancelled
            if stop {
                break
            }
        }
    }
    
    fileprivate func runToKeyframe(keyframe:Keyframe) {
        // Currently this completely ignores speed requests... a limitation of using AccelStepper with the AFMS
        SliderSerialInterface.shared.runCoordinatedMotionToPosition(slider: keyframe.sliderPosition!,
                                                                    pan: keyframe.panPosition!,
                                                                    tilt: keyframe.tiltPosition!,
                                                                    focus: keyframe.focusPosition!)
        var working = true
        while (working) {
            sleep(1)
            if SliderSerialInterface.shared.sliderState == .holding &&
                SliderSerialInterface.shared.panState == .holding &&
                SliderSerialInterface.shared.tiltState == .holding &&
                SliderSerialInterface.shared.focusState == .holding {
                working = false;
            }
        }
    }

    fileprivate func runComplete() {
        running = false
    }

    func cancel () {
        stop = true
    }
}
