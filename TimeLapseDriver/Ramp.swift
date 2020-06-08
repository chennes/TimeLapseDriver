//
//  Ramp.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/19/20.
//

import Foundation

final class Ramp: ObservableObject {
    
    let vstart:UInt32 = 1
    @Published var a1:UInt32 = 1000
    @Published var v1:UInt32 = 5000
    @Published var amax:UInt32 = 2000
    @Published var vmax:UInt32 = 51200
    @Published var dmax:UInt32 = 2000
    @Published var d1:UInt32 = 5000
    let vstop:UInt32 = 10
    
    enum TravelPhase {
        case phase1 // We stopped accelerating before reaching v1
        case phase2 // We stopped accelerating after v1, but before vmax
        case normal // We reached vmax
    }
    
    /**
     For the given six-stage velocity ramp this object represents, determine the time it will take to travel a given number of microsteps.
     */
    func getTravelTime(distance:UInt32) -> (Double,TravelPhase) {
        let t1:Double = Double(v1-vstart)/Double(a1)
        let t2:Double = Double(vmax-v1)/Double(amax)
        // t3 will be the time spent at vmax....
        let t4:Double = Double(vmax-v1)/Double(dmax) // Decelerations are given as positive numbers
        let t5:Double = Double(v1-vstop)/Double(d1)
        
        // Figure out how far we travelled in each velocity segment, assuming perfectly linear acceleration, etc.
        let dist1:Double = t1 * Double(v1-vstart)/2.0 + t1*Double(vstart)
        let dist2:Double = t2 * Double(vmax-v1)/2.0  + t2*Double(v1)
        // dist3 is the main travel distance
        let dist4:Double = t4 * Double(vmax-1)/2.0  + t4*Double(v1)
        let dist5:Double = t5 * Double(v1-vstop)/2.0 + t5*Double(vstop)
        
        // Now, see if we actually reach vmax:
        if dist1+dist2+dist4+dist5 > Double(distance) {
            // Nope: so we need to figure out where the stepper is going to stop the acceleration to switch to deceleration
            if dist1+dist5 > Double(distance) {
                // We never make it out of the first acceleration phase. Assume the acceleration is constant (zero jerk):
                let da = a1+d1 // d1 is given as positive, but is really negative
                let dv = vstart-vstop
                
                let A = Double((a1+da*da)/2)
                let B = Double(vstart + da*dv/2 + vstop*da/d1)
                let C = Double(dv*dv/2 + vstop*dv/d1 - distance)
                
                let t1Actual = (-B + sqrt(B*B-4*A*C)) / (2*A)
                let t5Actual = (Double(a1)*t1Actual + Double(vstart - vstop)) / -Double(d1)
                
                let tActual = t1Actual + t5Actual
                return (tActual, .phase1)
                
            } else {
                // We make it into the second acceleration phase. This can be treated with the same equation as the first phase if
                // we first subtract off the starting region and ending region, whose parameters we know. It's a bit simpler because
                // the start and stop velocities are the same, only the accelerations differ.
                let middleDistance = Double(distance) - dist1 - dist5
                
                let da = amax+dmax // dmax is given as positive, but is actually negative
                
                let A = Double((amax+da*da)/2)
                let B = Double(v1 + v1*da/dmax)
                let C = middleDistance
                
                let t2Actual = (-B + sqrt(B*B-4*A*C)) / (2*A)
                let t4Actual = (Double(amax)*t2Actual) / -Double(dmax)
                
                let tActual = t2Actual + t4Actual + t1 + t5
                return (tActual,.phase2)
            }
        } else {
            // Yes, the normal case. Find out how long we are at vmax:
            let dist3 = Double(distance) - dist1 - dist2 - dist4 - dist5
            let t3 = dist3 / Double(vmax)
            return (t1 + t2 + t3 + t4 + t5, .normal)
        }
    }
    
}
