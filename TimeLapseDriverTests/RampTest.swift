//
//  RampTest.swift
//  TimeLapseDriverTests
//
//  Created by Chris Hennes on 10/5/20.
//

import XCTest

class RampTest: XCTestCase {

    func testTravelTimeForNormalRamp() throws {
        // This is a ramp that is reasonable for the main slider action. Note that the units for all of these are the internal
        // Trinamic units. So also calculate them in real units, for easier coding below...
        let ramp = Ramp(a1: 1000, v1: 5000, amax: 2000, vmax: 102400, dmax: 4000, d1: 2000)
        let v1 = ramp.velocityInRealUnits(v: 5000)
        let a1 = ramp.accelerationInRealUnits(a: 1000)
        let amax = ramp.accelerationInRealUnits(a: 2000)
        let vmax = ramp.velocityInRealUnits(v: 102400)
        let d1 = ramp.accelerationInRealUnits(a: 2000)
        let dmax = ramp.accelerationInRealUnits(a: 4000)
        let vStart = ramp.velocityInRealUnits(v: 1)
        let vStop = ramp.velocityInRealUnits(v: 10)
        
        // First test: so short that we never leave the first acceleration region
        let levelOneTargetTime = (v1-vStart)/a1 + (v1-vStop)/d1
        let l1r1Time = (v1-vStart)/a1
        let l1r5Time = (v1-vStop)/d1
        let l1r1Distance = 0.5*l1r1Time*(v1-vStart) + l1r1Time*vStart
        let l1r5Distance = 0.5*l1r5Time*(v1-vStop) + l1r5Time*vStop
        let levelOneTest = ramp.getTravelTime(distance: UInt32(l1r1Distance+l1r5Distance)).0
        XCTAssertEqual(levelOneTest, levelOneTargetTime, accuracy: 0.001)
        
        // Second test: long enough to hit the second acceleration region
        let l2r2Time = (vmax-v1)/amax
        let l2r4Time = (vmax-v1)/dmax
        let levelTwoTargetTime = levelOneTargetTime + l2r2Time + l2r4Time
        let l2r2Distance = 0.5*l2r2Time*(vmax-v1) + l2r2Time*v1
        let l2r4Distance = 0.5*l2r4Time*(vmax-v1) + l2r4Time*v1
        let l2Distance = l1r1Distance + l2r2Distance + l2r4Distance + l1r5Distance
        let levelTwoTest = ramp.getTravelTime(distance: UInt32(l2Distance)).0
        XCTAssertEqual(levelTwoTest, levelTwoTargetTime, accuracy: 0.001)
        
        // Third test: long enough that we enter the main travel phase
        let l3r3Time = 1.0
        let levelThreeTargetTime = levelTwoTargetTime + l3r3Time
        let l3r3Distance = l3r3Time*vmax
        let l3Distance = l2Distance + l3r3Distance
        let levelThreeTest = ramp.getTravelTime(distance: UInt32(l3Distance)).0
        XCTAssertEqual(levelThreeTest, levelThreeTargetTime, accuracy: 0.001)
    }
    
    func testTravelTimeForSlowRamp() {
        // This is a ramp that is very slow: perhaps to go a short distance in a very long time
        let ramp = Ramp(a1: 1000, v1: 5000, amax: 2000, vmax: 100, dmax: 4000, d1: 2000)
        let v1 = ramp.velocityInRealUnits(v: 100)
        let a1 = ramp.accelerationInRealUnits(a: 1000)
        let amax = ramp.accelerationInRealUnits(a: 2000)
        let vmax = ramp.velocityInRealUnits(v: 100)
        let d1 = ramp.accelerationInRealUnits(a: 2000)
        let dmax = ramp.accelerationInRealUnits(a: 4000)
        let vStart = ramp.velocityInRealUnits(v: 1)
        let vStop = ramp.velocityInRealUnits(v: 10)
        
        // First test: so short that we never leave the first acceleration region
        let levelOneTargetTime = (v1-vStart)/a1 + (v1-vStop)/d1
        let l1r1Time = (v1-vStart)/a1
        let l1r5Time = (v1-vStop)/d1
        let l1r1Distance = 0.5*l1r1Time*(v1-vStart) + l1r1Time*vStart
        let l1r5Distance = 0.5*l1r5Time*(v1-vStop) + l1r5Time*vStop
        let levelOneTest = ramp.getTravelTime(distance: UInt32(l1r1Distance+l1r5Distance)).0
        XCTAssertEqual(levelOneTest, levelOneTargetTime, accuracy: 0.1)
        
        // Second test: long enough to hit the second acceleration region
        let l2r2Time = (vmax-v1)/amax
        let l2r4Time = (vmax-v1)/dmax
        let levelTwoTargetTime = levelOneTargetTime + l2r2Time + l2r4Time
        let l2r2Distance = 0.5*l2r2Time*(vmax-v1) + l2r2Time*v1
        let l2r4Distance = 0.5*l2r4Time*(vmax-v1) + l2r4Time*v1
        let l2Distance = l1r1Distance + l2r2Distance + l2r4Distance + l1r5Distance
        let levelTwoTest = ramp.getTravelTime(distance: UInt32(l2Distance)).0
        XCTAssertEqual(levelTwoTest, levelTwoTargetTime, accuracy: 0.1)
        
        // Third test: long enough that we enter the main travel phase
        let l3r3Time = 1.0
        let levelThreeTargetTime = levelTwoTargetTime + l3r3Time
        let l3r3Distance = l3r3Time*vmax
        let l3Distance = l2Distance + l3r3Distance
        let levelThreeTest = ramp.getTravelTime(distance: UInt32(l3Distance)).0
        XCTAssertEqual(levelThreeTest, levelThreeTargetTime, accuracy: 0.1)
    }
    
    func testTravelTimeForShortDistances() {
        let ramp = Ramp(a1: 1000, v1: 5000, amax: 2000, vmax: 102400, dmax: 4000, d1: 2000)
        let v1 = ramp.velocityInRealUnits(v: 5000)
        let a1 = ramp.accelerationInRealUnits(a: 1000)
        let amax = ramp.accelerationInRealUnits(a: 2000)
        let vmax = ramp.velocityInRealUnits(v: 102400)
        let d1 = ramp.accelerationInRealUnits(a: 2000)
        let dmax = ramp.accelerationInRealUnits(a: 4000)
        let vStart = ramp.velocityInRealUnits(v: 1)
        let vStop = ramp.velocityInRealUnits(v: 10)
        
        let distance1:UInt32 = 10
        let levelOneTest = ramp.getTravelTime(distance: distance1).0
        XCTAssertEqual(levelOneTest, 0.0159795, accuracy: 0.00001)
        
        let distance2:UInt32 = 100
        let level2Test = ramp.getTravelTime(distance: distance2).0
        XCTAssertEqual(level2Test, 0.050690, accuracy: 0.00001)
        
        let distance3:UInt32 = 1000
        let level3Test = ramp.getTravelTime(distance: distance3).0
        XCTAssertEqual(level3Test, 0.152679, accuracy: 0.00001)
    }

    
    func testCreatingRampForTargetTime() {
        
        let startingRamp = Ramp(a1: 1000, v1: 5000, amax: 2000, vmax: 102400, dmax: 4000, d1: 2000)
        var distance:UInt32 = 1000
        let time = 10.0
        
        while distance < 1000000 {
            let t0 = startingRamp.getTravelTime(distance: distance)
            let iteration1 = Ramp.createRequiredRamp(from: startingRamp, toTravel: distance, inSeconds: time, maxIterations: 1)
            let t1 = iteration1.getTravelTime(distance: distance)
            XCTAssertLessThan(fabs(t1.0-time), fabs(t0.0-time), "Travel time increased after the first iteration")
            let iteration2 = Ramp.createRequiredRamp(from: iteration1, toTravel: distance, inSeconds: time, maxIterations: 1)
            let t2 = iteration2.getTravelTime(distance: distance)
            XCTAssertLessThan(fabs(t2.0-time), fabs(t1.0-time), "Travel time increased after the second iteration")
            let iteration3 = Ramp.createRequiredRamp(from: iteration2, toTravel: distance, inSeconds: time, maxIterations: 1)
            let t3 = iteration3.getTravelTime(distance: distance)
            XCTAssertLessThan(fabs(t3.0-time), fabs(t2.0-time), "Travel time increased after the third iteration")
            XCTAssertEqual(t3.0, time, accuracy: 0.1)
            distance *= 10
        }
    }

}
