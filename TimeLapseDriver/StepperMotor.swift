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
    
    @Published var target: Int32 = 0
    @Published var ramp:Ramp
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
        ramp = DefaultRamp[code] ?? Ramp()
        NotificationCenter.default.addObserver(self, selector: #selector(onDidInitializeSlider(_:)), name: .didInitializeSlider, object: nil)
        
        positionSubscription = SliderCommunicationInterface.shared.positionPublisher[Int(code.rawValue)].assign(to: \StepperMotor.position, on: self)
        velocitySubscription = SliderCommunicationInterface.shared.velocityPublisher[Int(code.rawValue)].assign(to: \StepperMotor.velocity, on: self)
        stateSubscription = SliderCommunicationInterface.shared.statePublisher[Int(code.rawValue)].sink(receiveValue: { (value:UInt8) in
            self.state = StepperState(rawValue:value) ?? .holding
        })

    }
    
    @objc fileprivate func onDidInitializeSlider (_ notification: Notification) {
        SliderCommunicationInterface.shared.setRamp(stepper: self.code, ramp: self.ramp)
    }

}
