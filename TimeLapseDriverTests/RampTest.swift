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
        
        let distance1:UInt32 = 10
        let levelOneTest = ramp.getTravelTime(distance: distance1)
        // Excel Result: 1.597958659E-02
        XCTAssertEqual(levelOneTest.0, 1.597958659E-02, accuracy: 0.00001)
        XCTAssertEqual(levelOneTest.1, .phase1)
        
        // Max steps still in phase 1
        let distance2:UInt32 = 146
        let level2Test = ramp.getTravelTime(distance: distance2)
        // Excel Result: 6.126469571E-02
        XCTAssertEqual(level2Test.0, 6.126469571E-02, accuracy: 0.00001)
        XCTAssertEqual(level2Test.1, .phase1)
        
        // Min steps to reach phase 2
        let distance3:UInt32 = 147
        let level3Test = ramp.getTravelTime(distance: distance3)
        // Excel Result: 6.146290911E-02
        XCTAssertEqual(level3Test.0, 6.146290911E-02, accuracy: 0.00001)
        XCTAssertEqual(level3Test.1, .phase2)
        
        // A bit into phase 2
        let distance4:UInt32 = 10000
        let level4Test = ramp.getTravelTime(distance: distance4)
        // Excel Result: 3.745947901E-01
        XCTAssertEqual(level4Test.0, 3.745947901E-01, accuracy: 0.00001)
        XCTAssertEqual(level4Test.1, .phase2)
        
        // Max steps still in phase 2
        let distance5:UInt32 = 30793
        let level5Test = ramp.getTravelTime(distance: distance5)
        // Excel Result: 6.453932505E-01
        XCTAssertEqual(level5Test.0, 6.453932505E-01, accuracy: 0.00001)
        XCTAssertEqual(level5Test.1, .phase2)
    }

    
    func testCreatingRampForTargetTime() {
        
        let startingRamp = Ramp(a1: 1000, v1: 5000, amax: 2000, vmax: 102400, dmax: 4000, d1: 2000)
        var distance:UInt32 = 1000
        let time = 10.0
        
        while distance < 1000000 {
            let t0 = startingRamp.getTravelTime(distance: distance)
            let iteration1 = Ramp.createRequiredRamp(from: startingRamp, toTravel: distance, inSeconds: time, maxIterations: 1)
            let t1 = iteration1.getTravelTime(distance: distance)
            XCTAssertLessThanOrEqual(fabs(t1.0-time), fabs(t0.0-time), "Travel time increased after the first iteration")
            let iteration2 = Ramp.createRequiredRamp(from: iteration1, toTravel: distance, inSeconds: time, maxIterations: 1)
            let t2 = iteration2.getTravelTime(distance: distance)
            XCTAssertLessThanOrEqual(fabs(t2.0-time), fabs(t1.0-time), "Travel time increased after the second iteration")
            let iteration3 = Ramp.createRequiredRamp(from: iteration2, toTravel: distance, inSeconds: time, maxIterations: 1)
            let t3 = iteration3.getTravelTime(distance: distance)
            XCTAssertLessThanOrEqual(fabs(t3.0-time), fabs(t2.0-time), "Travel time increased after the third iteration for d=\(distance)")
            XCTAssertEqual(t3.0, time, accuracy: 0.1)
            distance *= 10
        }
    }

}
