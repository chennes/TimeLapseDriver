//
//  Keyframe.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 4/21/20.
//

import Foundation

struct Keyframe: Hashable, Codable, Identifiable {
    var id: Int
    var time: Float
    var sliderPosition: Int32?
    var panPosition: Int32?
    var tiltPosition: Int32?
    var focusPosition: Int32?
}
