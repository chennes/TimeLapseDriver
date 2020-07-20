//
//  Ramp.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/19/20.
//

import Foundation

final class Ramp: ObservableObject, NSCopying {
    
    
    let vstart:UInt32 = 1
    @Published var a1:UInt32 = 1000
    @Published var v1:UInt32 = 5000
    @Published var amax:UInt32 = 2000
    @Published var vmax:UInt32 = 51200
    @Published var dmax:UInt32 = 2000
    @Published var d1:UInt32 = 5000
    let vstop:UInt32 = 10
    
    private let fClk:UInt32 = 16000000 // 16MHz clock frequency
    
    enum TravelPhase {
        case phase1 // We stopped accelerating before reaching v1
        case phase2 // We stopped accelerating after v1, but before vmax
        case normal // We reached vmax
    }
    
    init () {
        // Do nothing
    }
    
    init (a1:UInt32, v1:UInt32, amax:UInt32, vmax:UInt32, dmax:UInt32, d1:UInt32) {
        self.a1 = a1
        self.v1 = v1
        self.amax = amax
        self.vmax = vmax
        self.dmax = dmax
        self.d1 = d1
    }
    
    init (ramp:Ramp) {
        self.a1 = ramp.a1
        self.v1 = ramp.v1
        self.amax = ramp.amax
        self.vmax = ramp.vmax
        self.dmax = ramp.dmax
        self.d1 = ramp.d1
    }
    
    /// Calculate the velocity in microsteps per second
    func velocityInRealUnits (v:UInt32) -> Double {
        // TMC5041_datasheet.pdf p. 53
        let factor = Double(fClk) / 2.0 / 8388608.0 // 2^23 = 8,388,608
        return Double(v) * factor
    }
    
    /// Calculate the acceleration in microsteps per second per second
    func accelerationInRealUnits (a:UInt32) -> Double {
        // TMC5041_datasheet.pdf p. 53
        let factor = Double(fClk)*Double(fClk)/(512.0*256.0)/16777216.0 // 2^24 = 16,777,216
        return Double(a) * factor
    }
    
    func velocityInTrinamicUnits(v:Double) -> UInt32 {
        let factor = Double(fClk) / 2.0 / 8388608.0 // 2^23 = 8,388,608
        return UInt32(abs(v / factor))
    }
    
    func accelerationInTrinamicUnits(a:Double) -> UInt32 {
        let factor = Double(fClk)*Double(fClk)/(512.0*256.0)/16777216.0 // 2^24 = 16,777,216
        return UInt32(abs(a / factor))
    }
    
    /**
     For the given six-stage velocity ramp this object represents, determine the time it will take to travel a given number of microsteps.
     */
    func getTravelTime(distance:UInt32) -> (Double,TravelPhase) {
        
        if distance == 0 {
            return (0.0,.normal)
        }
        
        let vstartu = velocityInRealUnits(v:vstart)
        let v1u = velocityInRealUnits(v:v1)
        let vmaxu = velocityInRealUnits(v:vmax)
        let vstopu = velocityInRealUnits(v:vstop)
        
        let a1u = accelerationInRealUnits(a: a1)
        let amaxu = accelerationInRealUnits(a: amax)
        let dmaxu = accelerationInRealUnits(a: dmax)
        let d1u = accelerationInRealUnits(a: d1)
        
        let t1 = (v1u-vstartu)/a1u
        let t2 = (vmaxu-v1u)/amaxu
        // t3 will be the time spent at vmax....
        let t4 = (vmaxu-v1u)/dmaxu // Decelerations are given as positive numbers
        let t5 = (v1u-vstopu)/d1u
        
        // Figure out how far we travelled in each velocity segment, assuming perfectly linear acceleration, etc.
        let dist1 = t1 * (v1u-vstartu)/2.0 + t1*vstartu
        let dist2 = t2 * (vmaxu-v1u)/2.0  + t2*v1u
        // dist3 is the main travel distance
        let dist4 = t4 * (vmaxu-v1u)/2.0  + t4*v1u
        let dist5 = t5 * (v1u-vstopu)/2.0 + t5*vstopu
        
        // Now, see if we actually reach vmax:
        if dist1+dist2+dist4+dist5 > Double(distance) {
            // Nope: so we need to figure out where the stepper is going to stop the acceleration to switch to deceleration
            if dist1+dist5 > Double(distance) {
                // We never make it out of the first acceleration phase. Just take a quick estimate, we can do the real math later
                let tActual = (t1 + t5) * (dist1+dist5) / Double(distance)
                return (tActual, .phase1)
                
            } else {
                let tActual = t1 + t5 + (t2 + t4) * (dist1+dist2+dist4+dist5) / Double(distance)
                // We make it into the second acceleration phase.
                return (tActual,.phase2)
            }
        } else {
            // Yes, the normal case. Find out how long we are at vmax:
            let dist3 = Double(distance) - dist1 - dist2 - dist4 - dist5
            let t3 = dist3 / vmaxu
            return (t1 + t2 + t3 + t4 + t5, .normal)
        }
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let newRamp = Ramp()
        newRamp.a1 = self.a1
        newRamp.v1 = self.v1
        newRamp.amax = self.amax
        newRamp.vmax = self.vmax
        newRamp.dmax = self.dmax
        newRamp.d1 = self.d1
        return newRamp
    }
    
}
