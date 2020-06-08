//
//  StepperMotor.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/7/20.
//

import Foundation
import Combine


class StepperMotor: ObservableObject, Identifiable {
    var id = UUID()
    typealias Input = Int32
    typealias Failure = Never
    
    let code: StepperMotorCode
    
    /// Position is really just a mirror for the actual physical position of the stepper: setting it has no external effect, it's purely feedback from the stepper.
    @Published private(set) var position: Int32 = 0
    private var positionSubscription: AnyCancellable?
    
    /// Velocity is really just a mirror for the actual physical velocity of the stepper: setting it has no external effect, it's purely feedback from the stepper.
    @Published private(set) var velocity: Int32 = 0
    private var velocitySubscription: AnyCancellable?
    
    /// State is really just a mirror for the actual physical state of the stepper: setting it has no external effect, it's purely feedback from the stepper.
    @Published private(set) var state: StepperState = .freewheeling
    private var stateSubscription: AnyCancellable?
    
    @Published var target: Int32 = 0 {
        didSet {
            // Push this out to the actual stepper
        }
    }
    @Published var ramp = Ramp() {
        didSet {
            // Push this out to the actual stepper
        }
    }
  
    @Published var isMoving: Bool = false
    
    var name: String {
        switch code {
        case .slider:
            return "Slider"
        case .pan:
            return "Pan"
        case .tilt:
            return "Tilt"
        case .focus:
            return "Focus"
        }
    }
    
    init (code: StepperMotorCode) {
        self.code = code
        switch self.code {
        case .slider:
            positionSubscription = SliderSerialInterface.shared.$sliderPosition.assign(to: \StepperMotor.position, on: self)
            velocitySubscription = SliderSerialInterface.shared.$sliderSpeed.assign(to: \StepperMotor.velocity, on: self)
            stateSubscription = SliderSerialInterface.shared.$sliderState.assign(to: \StepperMotor.state, on: self)
        case .pan:
            positionSubscription = SliderSerialInterface.shared.$panPosition.assign(to: \StepperMotor.position, on: self)
            velocitySubscription = SliderSerialInterface.shared.$panSpeed.assign(to: \StepperMotor.velocity, on: self)
            stateSubscription = SliderSerialInterface.shared.$panState.assign(to: \StepperMotor.state, on: self)
        case .tilt:
            positionSubscription = SliderSerialInterface.shared.$tiltPosition.assign(to: \StepperMotor.position, on: self)
            velocitySubscription = SliderSerialInterface.shared.$tiltSpeed.assign(to: \StepperMotor.velocity, on: self)
            stateSubscription = SliderSerialInterface.shared.$tiltState.assign(to: \StepperMotor.state, on: self)
        case .focus:
            positionSubscription = SliderSerialInterface.shared.$focusPosition.assign(to: \StepperMotor.position, on: self)
            velocitySubscription = SliderSerialInterface.shared.$focusSpeed.assign(to: \StepperMotor.velocity, on: self)
            stateSubscription = SliderSerialInterface.shared.$focusState.assign(to: \StepperMotor.state, on: self)
        }
    }

}
