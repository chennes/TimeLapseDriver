//
//  Keyframe.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 4/21/20.
//

import Foundation

class Keyframe: Hashable, Identifiable, ObservableObject {

    
    var id: Int
    @Published var time: Float
    @Published var sliderPosition: Int32?
    @Published var panPosition: Int32?
    @Published var tiltPosition: Int32?
    @Published var focusPosition: Int32?
    @Published var distanceToTarget: Double? // In millimeters
    
    init (id:Int, time:Float, sliderPosition:Int32?, panPosition:Int32?, tiltPosition:Int32?, focusPosition:Int32?, distanceToTarget:Double?) {
        self.id = id
        self.time = time
        self.sliderPosition = sliderPosition
        self.panPosition = panPosition
        self.tiltPosition = tiltPosition
        self.focusPosition = focusPosition
        self.distanceToTarget = distanceToTarget
    }
    
    static func == (lhs: Keyframe, rhs: Keyframe) -> Bool {
        return rhs.time == lhs.time &&
            rhs.sliderPosition == lhs.sliderPosition &&
            rhs.panPosition == lhs.panPosition &&
            rhs.tiltPosition == lhs.panPosition &&
            rhs.focusPosition == lhs.focusPosition &&
            rhs.distanceToTarget == lhs.distanceToTarget
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.time)
        hasher.combine(self.sliderPosition)
        hasher.combine(self.panPosition)
        hasher.combine(self.tiltPosition)
        hasher.combine(self.focusPosition)
        hasher.combine(self.distanceToTarget)
    }
}
