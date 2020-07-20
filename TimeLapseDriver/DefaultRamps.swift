//
//  DefaultRamps.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/11/20.
//

import Foundation

// Empirically derived from the actual hardware characteristics

var DefaultRamp: [StepperMotorCode : Ramp] = [
.slider : Ramp(a1: 1000, v1: 5000, amax: 2000, vmax: 102400, dmax: 4000, d1: 2000),
.pan : Ramp(a1: 100, v1: 500, amax: 200, vmax: 5200, dmax: 400, d1: 200),
.tilt : Ramp(a1: 100, v1: 500, amax: 200, vmax: 5200, dmax: 400, d1: 200),
.focus : Ramp(a1: 100, v1: 500, amax: 200, vmax: 5120, dmax: 4000, d1: 2000) // The focus must be quite slow
]
