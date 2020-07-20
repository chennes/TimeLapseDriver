//
//  StepperState.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/29/20.
//

import Foundation

// Data structures for translating from the internal TMC5041 register data, as sent over BLE, into
// a more human-friendly format for UI display.

class SPIStatus : ObservableObject {
    @Published var reset: Bool = false
    @Published var driver1Error: Bool = false
    @Published var driver2Error: Bool = false
    @Published var velocityReached1: Bool = false
    @Published var velocityReached2: Bool = false
    @Published var statusStopLeft1: Bool = false
    @Published var statusStopLeft2: Bool = false
    // Bit 8 is reserved
    
    func parseBLEData(data:Data) {
        self.reset            = (data[0] & 0x01) >> 0 == 1
        self.driver1Error     = (data[0] & 0x02) >> 1 == 1
        self.driver2Error     = (data[0] & 0x04) >> 2 == 1
        self.velocityReached1 = (data[0] & 0x08) >> 3 == 1
        self.velocityReached2 = (data[0] & 0x10) >> 4 == 1
        self.statusStopLeft1  = (data[0] & 0x20) >> 5 == 1
        self.statusStopLeft2  = (data[0] & 0x40) >> 6 == 1
//
//        print ("SPI Status:")
//        print ("  Data: \(data[0])")
//        print ("  Reset: \(self.reset)")
//        print ("  Driver 1 Error: \(self.driver1Error)")
//        print ("  Driver 2 Error: \(self.driver2Error)")
//        print ("  Velocity 1 Reached: \(self.velocityReached1)")
//        print ("  Velocity 2 Reached: \(self.velocityReached2)")
//        print ("  Status Stop Left 1 \(self.statusStopLeft1)")
//        print ("  Status Stop Left 2 \(self.statusStopLeft2)")
    }
    
}

class GlobalStatus : ObservableObject {
    @Published var reset: Bool = false
    @Published var driver1Error: Bool = false
    @Published var driver2Error: Bool = false
    @Published var chargePumpUndervoltage: Bool = false
    
    func parseBLEData(data:Data) {
        // This is a 32 bit field, but only the final four bits are used.
        self.reset                  = (data[3] & 0x01) >> 0 == 1
        self.driver1Error           = (data[3] & 0x02) >> 1 == 1
        self.driver2Error           = (data[3] & 0x04) >> 2 == 1
        self.chargePumpUndervoltage = (data[3] & 0x08) >> 3 == 1
//        print ("Global Status:")
//        print ("  Reset: \(self.reset)")
//        print ("  Driver 1 Error: \(self.driver1Error)")
//        print ("  Driver 2 Error: \(self.driver2Error)")
//        print ("  Charge pump under voltage: \(self.chargePumpUndervoltage)")
    }
}

class RampStatus : ObservableObject {
    @Published var statusStopLeft: Bool = false
    @Published var statusStopRight: Bool = false
    @Published var statusLatchLeft: Bool = false
    @Published var statusLatchRight: Bool = false
    @Published var eventStopLeft: Bool = false
    @Published var eventStopRight: Bool = false
    @Published var eventStopStallguard: Bool = false
    @Published var eventPositionReached: Bool = false
    @Published var velocityReached: Bool = false
    @Published var positionReached: Bool = false
    @Published var velocityIsZero: Bool = false
    @Published var tZeroWaitActive: Bool = false
    @Published var secondMove: Bool = false
    @Published var stallguardStatus: Bool = false
    
    func parseBLEData(data:Data) {
        // This is a 32 bit data structure, but only the last 14 bits are used
        self.statusStopLeft       = (data[3] & 0x01) >> 0 == 1
        self.statusStopRight      = (data[3] & 0x02) >> 1 == 1
        self.statusLatchLeft      = (data[3] & 0x04) >> 2 == 1
        self.statusLatchRight     = (data[3] & 0x08) >> 3 == 1
        self.eventStopLeft        = (data[3] & 0x10) >> 4 == 1
        self.eventStopRight       = (data[3] & 0x20) >> 5 == 1
        self.eventStopStallguard  = (data[3] & 0x40) >> 6 == 1
        self.eventPositionReached = (data[3] & 0x80) >> 7 == 1
        self.velocityReached      = (data[2] & 0x01) >> 0 == 1
        self.positionReached      = (data[2] & 0x02) >> 1 == 1
        self.velocityIsZero       = (data[2] & 0x04) >> 2 == 1
        self.tZeroWaitActive      = (data[2] & 0x08) >> 3 == 1
        self.secondMove           = (data[2] & 0x10) >> 4 == 1
        self.stallguardStatus     = (data[2] & 0x20) >> 5 == 1
//        print ("Ramp Status:")
//        print ("  Status stop left: \(statusStopLeft)")
//        print ("  Status stop right: \(statusStopRight)")
//        print ("  Status latch left: \(statusLatchLeft)")
//        print ("  Status latch right: \(statusLatchRight)")
//        print ("  Event stop left: \(eventStopLeft)")
//        print ("  Event stop right: \(eventStopRight)")
//        print ("  Event stop Stallguard: \(eventStopStallguard)")
//        print ("  Event position reached: \(eventPositionReached)")
//        print ("  Velocity reached: \(velocityReached)")
//        print ("  Position reached: \(positionReached)")
//        print ("  Velocity is zero: \(velocityIsZero)")
//        print ("  tZeroWait active: \(tZeroWaitActive)")
//        print ("  Second move: \(secondMove)")
//        print ("  Stallguard status: \(stallguardStatus)")
    }
}

class DriverStatus : ObservableObject {
    @Published var stallguardResult: UInt16 = 0 // Actually only ten bits, but who's counting?
    @Published var fullstepsActive: Bool = false
    @Published var actualMotorCurrent: UInt8 = 0 // Actually only five bits
    @Published var stallguardActive: Bool = false
    @Published var overtemp: Bool = false
    @Published var overtempPrewarning: Bool = false
    @Published var shortToGroundA: Bool = false
    @Published var shortToGroundB: Bool = false
    @Published var openLoadA: Bool = false
    @Published var openLoadB: Bool = false
    @Published var standstill: Bool = false
    
    func parseBLEData(data:Data) {
        // All 32 bits are used here, but they are not all booleans...
        // Pull the booleans out first:
        self.fullstepsActive    = (data[2] & 0x80) >> 7 == 1
        self.stallguardActive   = (data[0] & 0x01) >> 0 == 1
        self.overtemp           = (data[0] & 0x02) >> 1 == 1
        self.overtempPrewarning = (data[0] & 0x04) >> 2 == 1
        self.shortToGroundA     = (data[0] & 0x08) >> 3 == 1
        self.shortToGroundB     = (data[0] & 0x10) >> 4 == 1
        self.openLoadA          = (data[0] & 0x20) >> 5 == 1
        self.openLoadB          = (data[0] & 0x40) >> 6 == 1
        self.standstill         = (data[0] & 0x80) >> 7 == 1
        
        // There are two multi-bit integer values in there: fortunately, they do fall on even
        // byte boundaries (presumably by design, since there is padding in there).
        self.actualMotorCurrent = data[2] & 0x1F
        
        // The stallguard data is actually 10 bits, just to be extra awkward
        let temp16 = data[0...1].withUnsafeBytes({ (data: UnsafeRawBufferPointer) in
            Array<UInt16>(data.bindMemory(to: UInt16.self)) })
        self.stallguardResult = temp16[0] & 0x03FF
    }
}

class BoardStatus : ObservableObject {
    @Published var spiStatus:SPIStatus = SPIStatus()
    @Published var globalStatus:GlobalStatus = GlobalStatus()
    @Published var rampStatus:[RampStatus] = [RampStatus(), RampStatus()]
    @Published var driverStatus:[DriverStatus] = [DriverStatus(), DriverStatus()]
    @Published var xActual:[Int32] = [0,0]
    
    
    func parseBLEData(data:Data) {
        // 29 bytes total:
        // 0 : SPI Status
        // 1-4 : GSTAT
        // 5-8 : DRV_STATUS(1)
        // 9-12 : DRV_STATUS(2)
        // 13-16 : RAMP_STAT(1)
        // 17-20 : RAMP_STAT(2)
        // 21-24 : XACTUAL(1)
        // 25-28 : XACTUAL(2)
        spiStatus.parseBLEData(data: data.subdata(in: Range(uncheckedBounds: (0,1))))
        globalStatus.parseBLEData(data: data.subdata(in: Range(uncheckedBounds: (1,5))))
        driverStatus[0].parseBLEData(data: data.subdata(in: Range(uncheckedBounds: (5,9))))
        driverStatus[1].parseBLEData(data: data.subdata(in: Range(uncheckedBounds: (9,13))))
        rampStatus[0].parseBLEData(data: data.subdata(in: Range(uncheckedBounds: (13,17))))
        rampStatus[1].parseBLEData(data: data.subdata(in: Range(uncheckedBounds: (17,21))))
        
        let xActualData = data[21...28]
        xActual = xActualData.withUnsafeBytes({ (data: UnsafeRawBufferPointer) in
            Array<Int32>(data.bindMemory(to: Int32.self))
        })
        
    }
}

class SystemStatus : ObservableObject {
    @Published var boardStatus:[BoardStatus] = [BoardStatus(), BoardStatus()]
    
    func parseBLEData(data:Data) {
        let dataSize = data.count
        if dataSize != 58 {
            print("Expected 58 bytes of data, but received \(dataSize)")
        } else {
            // 29 bytes per board:
            let dataBoard1 = data.subdata(in: Range(uncheckedBounds: (0,29)))
            let dataBoard2 = data.subdata(in: Range(uncheckedBounds: (29,58)))
            boardStatus[0].parseBLEData(data: dataBoard1)
            boardStatus[1].parseBLEData(data: dataBoard2)
        }
    }
}
