//
//  MasterController.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/7/20.
//

import Foundation
import GameController
import Combine

final class MasterController: ObservableObject
{
    enum KeyframeTimeField:Int {
        case hours = 0
        case minutes = 1
        case seconds = 2
    }
    
    enum MasterState {
        case idle
        case live
        case traveling
        case continuous
        case timelapse
        case waiting
    }
    
    /**
     The current state of the system.
     */
    @Published var currentState:MasterState = .idle
    
    /**
     An ordered list of the upcoming states of the system. If the current state is not idle or live, this sequence will contain one or more states representing what
     state(s) to switch to when the current action completes. Some states have positions associated with them - those are also kept here
     */
    private var stateSequence:[MasterState] = []
    private var travelPositions:[(position:[Int32],time:Double)] = []
    
    @Published var timelapse: Bool = true
    @Published var numTimelapseFrames: Int = 150 // e.g. five seconds at 30fps
    @Published var steppers:[StepperMotor] = [
        StepperMotor(code:.slider),
        StepperMotor(code:.pan),
        StepperMotor(code:.tilt),
        StepperMotor(code:.focus)
    ]
    @Published var keyframes:[Keyframe] = []
    
    @Published var stop = false
    
    // User interface elements that are manipulated by the D pad:
    @Published var nextKeyframeD: Double = 0.0
    @Published var nextKeyframeH: Int = 0
    @Published var nextKeyframeM: Int = 0
    @Published var nextKeyframeS: Double = 0.0
    
    private var controllerPollTimer: Timer?
    private var lowSpeedMode: Bool = false
    private var activeKeyframeTimeField:KeyframeTimeField = .seconds
    private var activity: NSObjectProtocol?

    @Published var liveMode = false {
        didSet {
            if liveMode == true && currentState == .idle {
                // Make sure we have a joystick connected, otherwise turn back off.
                findConnectedControllers()
                if selectedController == nil {
                    print ("No controller found")
                    liveMode = false
                    controllerPollTimer?.invalidate()
                } else {
                    print ("Starting polling")
                    controllerPollTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true, block: { timer in
                        self.pollController();
                    })
                }
            } else {
                controllerPollTimer?.invalidate()
                SliderCommunicationInterface.shared.stopMotion()
            }
        }
    }
    
    private var timelapseMoveTimer: Timer?
    private var timelapseSettleTimer: Timer?
    private var statusUpdateTimer: Timer?
    @Published var currentTimelapseFrame: Int = 0
    private var timelapseFrames:[Keyframe] = []
    
    
    private var continuousMoveTimer: Timer?
    @Published var currentContinuousFrame: Int = 0
    
    var controllers:[GCController] = []
    var selectedController:GCExtendedGamepad?
    
    // For target-follow mode these allow us to keep a specific point in the middle of the frame during a motion.
    private let sliderDistancePerStep = 777.5/1000000.0 // In millimeters (empirically determined)
    private let panRadiansPerStep = 2.0 * Double.pi / 502000.0 // In radians (empirically determined)
    
    
    
    // The commands the user can issue to the driver are:
    // Cancel
    // Go to position
    // Run (timelapse or continuous)
    //
    // Of these:
    //   Stop is instantaneous (basically) and returns immediately.
    //   All others are completely asynchronous, so from the user's perspective the function call returns immediately, before
    //     the requested action is even begun. This class contains an internal monitoring timer to keep track of those
    //     runs, and to ensure that a Stop event is obeyed.
    
    func cancel() {
        SliderCommunicationInterface.shared.stopMotion()
        currentState = .idle
        liveMode = false
        stateSequence.removeAll()
        travelPositions.removeAll()
        controllerPollTimer?.invalidate()
        timelapseMoveTimer?.invalidate()
        timelapseSettleTimer?.invalidate()
        statusUpdateTimer?.invalidate()
        continuousMoveTimer?.invalidate()
    }
    
    func goToPosition(_ position:[Int32], in time:Double) {
        if currentState != .idle {
            cancel()
        }
        stateSequence.append(.traveling)
        travelPositions.append((position,time))
        nextState()
    }
    
    func run () {
        if timelapse {
            runTimelapse(totalFrames: numTimelapseFrames)
        } else {
            currentContinuousFrame = 0
            runContinuous()
        }
    }
    
    func runTimelapse (totalFrames:Int) {
        configureTimelapse()
        stateSequence.append(.timelapse)
        nextState()
    }
    
    func runContinuous () {
        currentContinuousFrame = 0
        stateSequence.append(.timelapse)
        nextState()
    }
    
    
    /**
     This is the function that actually figures out, from the current state and the upcoming state, what actions need to be taken to get to that state.
     */
    fileprivate func nextState() {
        let nextState = stateSequence.count > 0 ? stateSequence.removeFirst() : .idle
        
        switch nextState {
        case .idle:
            cancel() // Anything that is running, end it.
        case .live:
            if currentState == .idle {
                liveMode = true
            }
        case .traveling:
            if travelPositions.count > 0 {
                let target = travelPositions.removeFirst()
                runCoordinatedMotionToPosition (target.position, in:target.time)
            } else {
                print ("No position to travel to!")
            }
        case .continuous:
            currentContinuousFrame += 1
            let nextSliderPosition = keyframes[currentContinuousFrame].sliderPosition  ?? Int32(0)
            let nextPanPosition = keyframes[currentContinuousFrame].panPosition  ?? Int32(0)
            let nextTiltPosition = keyframes[currentContinuousFrame].tiltPosition  ?? Int32(0)
            let nextFocusPosition = keyframes[currentContinuousFrame].focusPosition  ?? Int32(0)
            let nextPosition:[Int32] = [nextSliderPosition, nextPanPosition, nextTiltPosition, nextFocusPosition]
            let deltaT = Double(keyframes[currentContinuousFrame].time - keyframes[currentContinuousFrame-1].time)
            
            runCoordinatedMotionToPosition(nextPosition, in: deltaT)
            
            if currentContinuousFrame < keyframes.count-1 {
                stateSequence.append(.continuous)
                continuousMoveTimer = Timer.scheduledTimer(withTimeInterval: deltaT, repeats: false, block: { timer in
                    self.nextState()
                })
            }
            
        case .timelapse:
            SliderCommunicationInterface.shared.takePhoto()
            currentTimelapseFrame += 1
            if currentTimelapseFrame < timelapseFrames.count-1 {
                stateSequence.append(.timelapse)
                let deltaT = timelapseFrames[currentTimelapseFrame].time - timelapseFrames[currentTimelapseFrame-1].time
                timelapseMoveTimer = Timer.scheduledTimer(withTimeInterval: Double(deltaT), repeats: false, block: { timer in
                    self.nextState()
                })
            }
            let nextSliderPosition = timelapseFrames[currentTimelapseFrame].sliderPosition  ?? Int32(0)
            let nextPanPosition = timelapseFrames[currentTimelapseFrame].panPosition  ?? Int32(0)
            let nextTiltPosition = timelapseFrames[currentTimelapseFrame].tiltPosition  ?? Int32(0)
            let nextFocusPosition = timelapseFrames[currentTimelapseFrame].focusPosition  ?? Int32(0)
            let nextPosition:[Int32] = [nextSliderPosition, nextPanPosition, nextTiltPosition, nextFocusPosition]
            timelapseSettleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: {timer in
                self.stateSequence.insert(.waiting, at: 0)
                self.runCoordinatedMotionToPosition(position:nextPosition)
            })
        case .waiting:
            // During a wait, we do nothing: nextState() will be called again from a timer of some kind (well, it should be, and if it's not, it's a bug!)
            break
        }
    }
    
    
    fileprivate func configureTimelapse() {
        currentTimelapseFrame = 0

        if keyframes.isEmpty {
            print ("No keyframes set")
            return
        }
        if keyframes.count < 2 {
            print ("There must be at least two keyframes")
            return
        }

        // Construct a sequence of keyframes in between whatever frames are provided
        let totalTime = keyframes.last!.time
        let deltaT = totalTime / Float(numTimelapseFrames) // Assumed constant for the time being

        // Sanity checks
        if deltaT < 1.5 {
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
        var previousFrame = keyframes.first!
        timelapseFrames.append(previousFrame)
        for keyframe in keyframes.dropFirst() {
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
                let sliderPosition = previousFrame.sliderPosition!+Int32(round(subframe*deltaSlider))
                var panPosition = previousFrame.panPosition!+Int32(round(subframe*deltaPan))
                let tiltPosition = previousFrame.tiltPosition!+Int32(round(subframe*deltaTilt))
                let focusPosition = previousFrame.focusPosition!+Int32(round(subframe*deltaFocus))

                if (keyframe.distanceToTarget ?? 0.0) > 0.0 {
                    panPosition = getPositionFollowingPanFrom(sliderPosition: Int32(round(subframe*deltaSlider)), startDistanceToTarget: previousFrame.distanceToTarget ?? 0.0, endDistanceToTarget: keyframe.distanceToTarget ?? 0.0, totalSlideSteps: keyframe.sliderPosition! - previousFrame.sliderPosition!, totalPanSteps: keyframe.panPosition! - previousFrame.panPosition!)
                    print ("Pan position: \(panPosition)")
                }
                timelapseFrames.append(Keyframe(id: timelapseFrames.count,
                                                time: t,
                                                sliderPosition: sliderPosition,
                                                panPosition: panPosition,
                                                tiltPosition: tiltPosition,
                                                focusPosition: focusPosition,
                                                distanceToTarget: 0.0))
                subframe += 1.0
                t += deltaT
            }
            previousFrame = timelapseFrames.last!
        }
        timelapseFrames.append(keyframes.last!)
    }
    
    
    fileprivate func findConnectedControllers() {
        self.controllers = GCController.controllers()
        for controller in self.controllers {
            print ("Checking controller \(controller.vendorName ?? "(Unknown)")")
            if controller.extendedGamepad != nil {
                self.selectedController = controller.extendedGamepad
                self.selectedController?.valueChangedHandler = self.controllerChanged
                break // Let's select the first one, for my purposes there are never more...
            }
        }
    }

    fileprivate func discoverWirelessControllers() {
        GCController.startWirelessControllerDiscovery(completionHandler: {
            self.findConnectedControllers()
        })
    }

    fileprivate func pollController()
    {
        guard let controller = selectedController else {
            return
        }
        if currentState != .live {
            // Do not listen to the joystick input if we are not in live mode
            return
        }
        // We poll the three major axes we use and update the velocities accordingly
        let sliderInput = controller.leftThumbstick.xAxis.value
        //let focusInput = controller.leftThumbstick.yAxis.value
        let panInput = controller.rightThumbstick.xAxis.value
        let tiltInput = controller.rightThumbstick.yAxis.value

        // Focus is the analog triggers: use the difference between them as our value
        let focusInput = controller.rightTrigger.value - controller.leftTrigger.value

        let multiplier = lowSpeedMode ? Float (0.1) : Float(1.0)

        let sliderVMax = -Int32(multiplier * sliderInput * Float(steppers[0].ramp.vmax)) // Reverse the sense of the slide
        let panVMax = Int32(multiplier * panInput * Float(steppers[1].ramp.vmax))
        let tiltVMax = Int32(multiplier * tiltInput * Float(steppers[2].ramp.vmax))
        let focusVMax = Int32(focusInput * Float(steppers[3].ramp.vmax)) // Focus does not get the multiplier

        SliderCommunicationInterface.shared.runAtSpeed(velocity: [sliderVMax,panVMax,tiltVMax,focusVMax])
        //print ("Speeds: \(sliderVMax) \(panVMax) \(tiltVMax) \(focusVMax)")
    }

    fileprivate func controllerChanged(gamepad:GCExtendedGamepad, element:GCControllerElement) {
        // The control mapping is:
        // X: Take photo
        // Y: Zero

        // Figure out which element it was...
        if element == gamepad.buttonX {
            if gamepad.buttonX.isPressed {
                SliderCommunicationInterface.shared.takePhoto()
            }
        } else if element == gamepad.buttonY {
            if gamepad.buttonY.isPressed {
                SliderCommunicationInterface.shared.setZero()
            }
        } else if element == gamepad.buttonB {
            if gamepad.buttonB.isPressed {
                lowSpeedMode = !lowSpeedMode
            }
        } else if element == gamepad.buttonA {
            if gamepad.buttonA.isPressed {
                // Make sure that the keyframe time is non-zero
                var timeInSeconds = Float(self.nextKeyframeS)
                timeInSeconds += (Float(self.nextKeyframeM)) * 60
                timeInSeconds += (Float(self.nextKeyframeH)) * 3600
                if timeInSeconds <= 0.0 {
                    if keyframes.isEmpty {
                        timeInSeconds = 3600 // One hour is the default, to keep us out of trouble.
                    } else if keyframes.count == 1 {
                        timeInSeconds = keyframes.last!.time * 2 // If there was already a single keyframe, add this the same amount of time after
                    } else {
                        timeInSeconds = keyframes.last!.time + keyframes[1].time - keyframes[0].time // If there were more than one keyframe, calculate a delta time from the first two and add it to the last.
                    }
                }
                keyframes.append(Keyframe(id: keyframes.count, time: timeInSeconds,
                                          sliderPosition: steppers[0].position,
                                          panPosition: steppers[1].position,
                                          tiltPosition: steppers[2].position,
                                          focusPosition: steppers[3].position,
                                          distanceToTarget: 0.0))
            }
        } else if element == gamepad.dpad {
            if gamepad.dpad.left.isPressed {
                activeKeyframeTimeField = KeyframeTimeField(rawValue: activeKeyframeTimeField.rawValue - 1) ?? .seconds
            } else if gamepad.dpad.right.isPressed {
                activeKeyframeTimeField = KeyframeTimeField(rawValue: activeKeyframeTimeField.rawValue + 1) ?? .hours
            } else if gamepad.dpad.up.isPressed {
                switch activeKeyframeTimeField {
                case .hours: nextKeyframeH += 1
                case .minutes: nextKeyframeM += 1
                case .seconds: nextKeyframeS += 1
                }
            } else if gamepad.dpad.down.isPressed {
                switch activeKeyframeTimeField {
                case .hours: nextKeyframeH -= 1
                case .minutes: nextKeyframeM -= 1
                case .seconds: nextKeyframeS -= 1
                }
            }
        } else if element == gamepad.leftShoulder {
            if gamepad.leftShoulder.isPressed {
                SliderCommunicationInterface.shared.stopMotion()
                cancel()
            }
        } else if element == gamepad.rightShoulder {
            if gamepad.rightShoulder.isPressed {
                run()
            }
        }
    }

    func returnToZero () {
        runCoordinatedMotionToPosition(position: [0,0,0,0])
    }

    
    func runCoordinatedMotionToPosition (_ position: [Int32], in seconds:Double) {
        currentState = .traveling
        var distance:[UInt32] = [0,0,0,0]
        var time:[Double] = [0.0,0.0,0.0,0.0]
        for i in 0..<4 {
            distance[i] = UInt32(abs(SliderCommunicationInterface.shared.positionPublisher[i].value - position[i]))
            time[i] = steppers[i].ramp.getTravelTime(distance: distance[i]).0
        }

        let maxTime = time.max() ?? 0.0
        
        if maxTime > seconds {
            print ("Requested time for travel was not long enough to complete the motion!")
            return
        }

        // Now calculate the speed factors to employ:
        var factor:[Double] = [0.0,0.0,0.0,0.0]
        for i in 0..<4 {
            factor[i] = time[i]/seconds
        }
        
        // All of those factors are one or lower, by construction, so we can use them to slow down
        // the steppers. For now, the only thing to change is vmax, but in the future we could
        // consider getting fancier and trying to scale the whole acceleration curve, if that proves
        // to be needed.
        var ramp:[Ramp] = []
        for i in 0..<4 {
            ramp.append(steppers[i].ramp.copy() as! Ramp)
            if factor[i] > 0 {
                ramp[i].vmax = UInt32(factor[i] * Double(ramp[i].vmax))
            }
            SliderCommunicationInterface.shared.setRamp(stepper: StepperMotorCode(rawValue: UInt8(i))!, ramp: ramp[i])
        }
        stop = false

        // Calls to the SSI are basically asynchronous by construction, since they just transmit a command
        // over the Serial connection and then return, without waiting for the command to do anything
        // except acknowledge receipt.
        SliderCommunicationInterface.shared.travelToPosition(position:position)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            self.runCoordinatedMotionToPositionDispatch()
            DispatchQueue.main.async { [weak self] in
                self?.nextState()
            }
        }

    }
    
    func runCoordinatedMotionToPosition (position: [Int32]) {
        // Find the stepper that will take the longest:
        var distance:[UInt32] = [0,0,0,0]
        var time:[Double] = [0.0,0.0,0.0,0.0]
        for i in 0..<4 {
            distance[i] = UInt32(abs(SliderCommunicationInterface.shared.positionPublisher[i].value - position[i]))
            time[i] = steppers[i].ramp.getTravelTime(distance: distance[i]).0
        }

        let maxTime = time.max() ?? 0.0

        runCoordinatedMotionToPosition (position, in:maxTime)

    }

    func runCoordinatedMotionToPositionDispatch () {

        activity = ProcessInfo().beginActivity(options: .idleSystemSleepDisabled, reason: "Running Camera Slider")

        // Now we have to wait for this to actually happen...
        var working = true;
        while (working) {
            if SliderCommunicationInterface.shared.statePublisher[0].value == StepperState.holding.rawValue &&
                SliderCommunicationInterface.shared.statePublisher[1].value == StepperState.holding.rawValue &&
                SliderCommunicationInterface.shared.statePublisher[2].value == StepperState.holding.rawValue &&
                SliderCommunicationInterface.shared.statePublisher[3].value == StepperState.holding.rawValue {
                working = false;
            } else if stop {
                working = false
            }
        }
    }
//
//    fileprivate func nextState () {
//
//        if let pinfo = activity {
//            ProcessInfo().endActivity(pinfo)
//            activity = nil
//        }
//
//        // Set the ramps back in case they got changed (for example, by runCoordinated...)
//        SliderCommunicationInterface.shared.setRamp(stepper: .slider, ramp: steppers[0].ramp)
//        SliderCommunicationInterface.shared.setRamp(stepper: .pan, ramp: steppers[1].ramp)
//        SliderCommunicationInterface.shared.setRamp(stepper: .tilt, ramp: steppers[2].ramp)
//        SliderCommunicationInterface.shared.setRamp(stepper: .focus, ramp: steppers[3].ramp)
//
//        if stateSequence.first == nil {
//            currentState = .idle
//        } else {
//            currentState = stateSequence.removeFirst()
//            switch currentState {
//            case .idle:
//                print ("Idle found on the state stack.")
//            case .continuous:
//                print ("")
//            case .live:
//                liveMode = true
//            case .traveling:
//                print ("Traveling found on the state stack, but nowhere to go!")
//            case .zeroing:
//                returnToZero()
//            case .timelapse:
//                print ("Returning to timelapse hold mode")
//            }
//
//            statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
//                self.waitForHold();
//            })
//        }
//    }
//
//    func run () {
//        // Set up the run stack:
//        zeroWithBacklashProtection()
//        if timelapse {
//            stateSequence.append(.timelapse)
//        } else {
//            stateSequence.append(.continuous)
//        }
//
//        if currentState == .idle {
//            nextState()
//        }
//    }
//
    func getPositionFollowingPanFrom(sliderPosition:Int32, startDistanceToTarget:Double, endDistanceToTarget:Double, totalSlideSteps:Int32, totalPanSteps:Int32) -> Int32 {

        // First construct our base triangle with sides ABC and opposing angles abc. Use the law of sines to determine the angles from the sides.
        let A = Double(abs(totalSlideSteps)) * sliderDistancePerStep
        let a = Double(abs(totalPanSteps)) * panRadiansPerStep
        let ratio = A / sin(a)
        let B = startDistanceToTarget
        var C = endDistanceToTarget // We are actually going to let this float a bit, so we aren't overconstrained
        var b = asin(B/ratio) // Variable because we have to handle the ambiguous case (see below)

        // It is possible that under some circumstances angle b might actually be pi minus the calculated angle. To determine if this is the case
        // here, back-calculate distance C under both assumptions and see which is closer to the given C
        let cAlt1 = Double.pi - b - a
        let endDistanceAlt1 = ratio * sin(cAlt1)

        let bAlt2 = Double.pi - b
        let cAlt2 = Double.pi - bAlt2 - a
        if cAlt2 > 0 {
            let endDistanceAlt2 = ratio * sin(cAlt2)
            if abs(endDistanceAlt2-C) < abs(endDistanceAlt1-C) {
                b = bAlt2
            }
        }

        // DO NOT USE C in this calculation. We never use C except to check on the ambiguous case, otherwise we end up overconstrained
        // and will end up with a potential discontinuity in the middle.
        let c = Double.pi - b - a

        // Recalculate the new, "exact" C, assuming that the thing that's really important here is that angle a is actually traversed.
        C = ratio * sin(c)

        let internalSliderPosition = abs(sliderPosition)

        // Two branches which divide at the point of closest approach (though that point may be outside the actual requested slide, so never hit):
        let Ax = Double(internalSliderPosition) * sliderDistancePerStep
        var position:Int32 = 0
        if Ax < B * cos(c) {
            let bb = Ax * cos(c)
            let bc = Ax * sin(c)
            let ba = B - bb
            let phi = atan2(bc, ba)
            position = abs(Int32(phi/panRadiansPerStep))
        } else { // It has crossed the right triangle representing the point of closest approach to the target...
            let cb = (A-Ax) * cos(b)
            let cc = (A-Ax) * sin(b)
            let ca = C - cb
            let phi = a - atan2(cc, ca)
            position = abs(Int32(phi/panRadiansPerStep))
        }

        // If we are actually going in a negative direction, make sure to reverse this
        if totalPanSteps < 0 {
            position *= -1
        }

        return position

    }
//
//    fileprivate func waitForZero() {
//        let allZero = SliderCommunicationInterface.shared.positionPublisher.allSatisfy({(val:CurrentValueSubject<Int32, Never>) -> Bool in return val.value == 0 })
//        if (allZero) {
//            print ("All zero passed")
//            // We are at zero: go to the next step
//            if timelapse {
//                runTimelapse()
//            } else {
//                runSingleMotion()
//            }
//
//        } else if stop {
//            running = false
//            // Don't reset the timer, just bail out
//        } else {
//            statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
//                self.waitForZero();
//            })
//        }
//    }
//
//    fileprivate func runTimelapse() {
//        if keyframes.isEmpty {
//            print ("No keyframes set")
//            return
//        }
//        if keyframes.count < 2 {
//            print ("There must be at least two keyframes")
//            return
//        }
//
//        // Construct a sequence of keyframes in between whatever frames are provided
//        let totalTime = keyframes.last!.time
//        let deltaT = totalTime / Float(numTimelapseFrames) // Assumed constant for the time being
//
//        // Sanity checks
//        if deltaT < 1.0 {
//            print ("It is unlikely that the camera will be in position in time to take this number of keyframes. Bailing...")
//            cancel()
//            return
//        }
//
//        if deltaT > 14.5 * 60 { // Technically it's a 15 minute timer, but let's add some safety margin
//            print ("The camera will stop looking for IR signals before the next keyframe is triggered. Bailing...")
//            cancel()
//            return
//        }
//
//        var t:Float = 0.0
//        var previousFrame = keyframes.first!
//        timelapseFrames.append(previousFrame)
//        for keyframe in keyframes.dropFirst() {
//            // For every keyframe, figure out what fraction of the total time it represents
//            let majorDeltaT = keyframe.time - t
//            let keyframeFraction = majorDeltaT / totalTime
//            let numberOfMinorFrames = Int(round(keyframeFraction * Float(numTimelapseFrames)))
//
//            // Calculate the per-step deltas: calculate them as floats, we will round them during the next step
//            let deltaSlider = Float(keyframe.sliderPosition! - previousFrame.sliderPosition!) / Float(numberOfMinorFrames)
//            let deltaPan = Float(keyframe.panPosition! - previousFrame.panPosition!) / Float(numberOfMinorFrames)
//            let deltaTilt = Float(keyframe.tiltPosition! - previousFrame.tiltPosition!) / Float(numberOfMinorFrames)
//            let deltaFocus = Float(keyframe.focusPosition! - previousFrame.focusPosition!) / Float(numberOfMinorFrames)
//
//            var subframe:Float = 0
//            while t < keyframe.time {
//                let sliderPosition = previousFrame.sliderPosition!+Int32(round(subframe*deltaSlider))
//                var panPosition = previousFrame.panPosition!+Int32(round(subframe*deltaPan))
//                let tiltPosition = previousFrame.tiltPosition!+Int32(round(subframe*deltaTilt))
//                let focusPosition = previousFrame.focusPosition!+Int32(round(subframe*deltaFocus))
//
//                if (keyframe.distanceToTarget ?? 0.0) > 0.0 {
//                    panPosition = getPositionFollowingPanFrom(sliderPosition: Int32(round(subframe*deltaSlider)), startDistanceToTarget: previousFrame.distanceToTarget ?? 0.0, endDistanceToTarget: keyframe.distanceToTarget ?? 0.0, totalSlideSteps: keyframe.sliderPosition! - previousFrame.sliderPosition!, totalPanSteps: keyframe.panPosition! - previousFrame.panPosition!)
//                    print ("Pan position: \(panPosition)")
//                }
//                timelapseFrames.append(Keyframe(id: timelapseFrames.count,
//                                                time: t,
//                                                sliderPosition: sliderPosition,
//                                                panPosition: panPosition,
//                                                tiltPosition: tiltPosition,
//                                                focusPosition: focusPosition,
//                                                distanceToTarget: 0.0))
//                subframe += 1.0
//                t += deltaT
//            }
//            previousFrame = timelapseFrames.last!
//        }
//        timelapseFrames.append(keyframes.last!)
//
//        // OK, let's fire off a photo and then roll...
//        activity = ProcessInfo().beginActivity(options: .userInitiated, reason: "Running timelapse")
//        SliderCommunicationInterface.shared.takePhoto()
//
//        running = true
//        stop = false
//        nextTimelapseFrame()
//    }
//
//    fileprivate func nextTimelapseFrame () {
//        if stop {
//            timelapseMoveTimer?.invalidate()
//            timelapseSettleTimer?.invalidate()
//            running = false
//            return
//        }
//        // Triggered by the timelapse timer to advance to the next frame, trigger a photo, and reset the timer for the next frame.
//        SliderCommunicationInterface.shared.takePhoto()
//
//        // Reset the timer for the next photo, if there is one...
//        if currentTimelapseFrame < timelapseFrames.count-1 {
//            let deltaT = timelapseFrames[currentTimelapseFrame+1].time - timelapseFrames[currentTimelapseFrame].time
//            timelapseMoveTimer = Timer.scheduledTimer(withTimeInterval: Double(deltaT), repeats: false, block: { timer in
//                self.nextTimelapseFrame();
//            })
//            // For now, always allow one second for the photo to be taken before moving again. Eventually this should
//            // be configurable, obviously
//            let nextFrame = self.timelapseFrames[self.currentTimelapseFrame+1]
//            timelapseSettleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
//                self.moveToTimelapseFrame(keyframe:nextFrame);
//            })
//            currentTimelapseFrame += 1
//        } else {
//            running = false
//            stop = true
//        }
//    }
//
//    fileprivate func moveToTimelapseFrame(keyframe:Keyframe) {
//        if stop {
//            timelapseMoveTimer?.invalidate()
//            timelapseSettleTimer?.invalidate()
//            running = false
//            return
//        }
//        SliderCommunicationInterface.shared.travelToPosition(position: [keyframe.sliderPosition!,
//                                                                        keyframe.panPosition!,
//                                                                        keyframe.tiltPosition!,
//                                                                        keyframe.focusPosition!])
//    }
//
//    fileprivate func runSingleMotion() {
//        // For this we need to recalculate all of the ramps. For simplicity we assume that
//        // vstart = vstop = 0, and we will set v1 > vmax so that it's out of play entirely.
//        // That leaves a simple linear ramp. We will further assume that the deceleration at
//        // the end is irrelevant, and the stop essentially instantaneous. Finally, we assume
//        // that we are running at vmax for the vast majority of the time, so we can calculate
//        // the appropriate vmax just by dividing the distance by the time for each stepper.
//
//        var vMaxU = [0.0,0.0,0.0,0.0]
//        vMaxU[0] = Double( abs(Float(keyframes.last?.sliderPosition ?? 0) / (keyframes.last?.time ?? 1.0)) )
//        vMaxU[1] = Double( abs(Float(keyframes.last?.panPosition ?? 0) / (keyframes.last?.time ?? 1.0)) )
//        vMaxU[2] = Double( abs(Float(keyframes.last?.tiltPosition ?? 0) / (keyframes.last?.time ?? 1.0)) )
//        vMaxU[3] = Double( abs(Float(keyframes.last?.focusPosition ?? 0) / (keyframes.last?.time ?? 1.0)) )
//
//        var aMaxU = [steppers[0].ramp.accelerationInRealUnits(a: steppers[0].ramp.amax),
//                     steppers[1].ramp.accelerationInRealUnits(a: steppers[1].ramp.amax),
//                     steppers[2].ramp.accelerationInRealUnits(a: steppers[2].ramp.amax),
//                     steppers[3].ramp.accelerationInRealUnits(a: steppers[3].ramp.amax)]
//
//        // We want these all to accelerate such that they arrive at vmax at the same time, which is driven by
//        // the one that takes the longest to achieve that.
//        var timeToVMax = 0.0
//        for i in 0..<4 {
//            timeToVMax = max(timeToVMax, Double(vMaxU[i]) / Double(aMaxU[i]))
//        }
//
//        print ("timeToVMax = \(timeToVMax)")
//
//        // Now go back and recalculate the amaxes such that they all take timeToVMax to get there...
//        for i in 0..<4 {
//            aMaxU[i] = vMaxU[i] / timeToVMax
//        }
//
//        // Finally, convert both the velocities and accelerations into Trinamic internal units for sending to the chip:
//        let ramps = [Ramp(), Ramp(), Ramp(), Ramp()]
//        for i in 0..<4 {
//            ramps[i].vmax = ramps[i].velocityInTrinamicUnits(v:vMaxU[i])
//            ramps[i].v1 = ramps[i].velocityInTrinamicUnits(v:vMaxU[i])
//            ramps[i].amax = ramps[i].accelerationInTrinamicUnits(a:aMaxU[i])
//            ramps[i].dmax = ramps[i].accelerationInTrinamicUnits(a:aMaxU[i])
//            ramps[i].a1 = ramps[i].accelerationInTrinamicUnits(a:aMaxU[i])
//            ramps[i].d1 = ramps[i].accelerationInTrinamicUnits(a:aMaxU[i])
//            print ("Ramp \(i) vMax = \(ramps[i].vmax)")
//        }
//
//        // Set the ramps:
//        if ramps[0].vmax > 0 {
//            SliderCommunicationInterface.shared.setRamp(stepper: .slider, ramp: ramps[0])
//        }
//        if ramps[1].vmax > 0 {
//            SliderCommunicationInterface.shared.setRamp(stepper: .pan, ramp: ramps[1])
//        }
//        if ramps[2].vmax > 0 {
//            SliderCommunicationInterface.shared.setRamp(stepper: .tilt, ramp: ramps[2])
//        }
//        if ramps[3].vmax > 0 {
//            SliderCommunicationInterface.shared.setRamp(stepper: .focus, ramp: ramps[3])
//        }
//
//        // Wait two seconds to give the serial communications a chance to complete: this makes debugging a bit easier...
//        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { timer in
//            self.triggerSingleMotion();
//        })
//    }
//
//    fileprivate func triggerSingleMotion() {
//        // Now, we're ready to actually run our motion, which should take APPROXIMATELY the amount of time we allowed for it
//        running = true
//        stop = false
//        let position = [keyframes.last?.sliderPosition ?? SliderCommunicationInterface.shared.positionPublisher[0].value,
//                        keyframes.last?.panPosition ?? SliderCommunicationInterface.shared.positionPublisher[1].value,
//                        keyframes.last?.tiltPosition ?? SliderCommunicationInterface.shared.positionPublisher[2].value,
//                        keyframes.last?.focusPosition ?? SliderCommunicationInterface.shared.positionPublisher[3].value]
//        SliderCommunicationInterface.shared.travelToPosition(position:position)
//
//        // Monitor the process and reset the ramps when it's done:
//        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
//            self.monitorSingleMotion();
//        })
//    }
//
//    fileprivate func monitorSingleMotion() {
//        let allHolding = SliderCommunicationInterface.shared.statePublisher.allSatisfy( {(state:CurrentValueSubject<UInt8, Never>) -> Bool in
//            return state.value == StepperState.holding.rawValue
//        } )
//        if stop || allHolding {
//            for i in 0..<4 {
//                SliderCommunicationInterface.shared.setRamp(stepper: StepperMotorCode(rawValue: UInt8(i))!, ramp: steppers[i].ramp)
//            }
//            running = false
//            if let pinfo = activity {
//                ProcessInfo().endActivity(pinfo)
//                activity = nil
//            }
//        } else {
//            statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
//                self.monitorSingleMotion();
//            })
//        }
//    }
//
//    func cancel () {
//        stop = true
//    }
}
