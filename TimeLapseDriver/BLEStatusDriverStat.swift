//
//  BLEStatusDriverStat.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/29/20.
//

import SwiftUI

// stallguardResult: UInt16 = 0 // Actually only ten bits, but who's counting?
// fullstepsActive: Bool = false
// actualMotorCurrent: UInt8 = 0 // Actually only five bits
// stallguardActive: Bool = false
// overtemp: Bool = false
// overtempPrewarning: Bool = false
// shortToGroundA: Bool = false
// shortToGroundB: Bool = false
// openLoadA: Bool = false
// openLoadB: Bool = false
// standstill: Bool = false

struct BLEStatusDriverStat: View {
    @EnvironmentObject var driverStat:DriverStatus
    var body: some View {
        VStack {
            Text("\(driverStat.stallguardResult)")
                .frame(width: 60, height: 24, alignment: .center)
            Text("\(driverStat.actualMotorCurrent)")
                .frame(width: 60, height: 24, alignment: .center)
            VStack {
                Circle()
                    .foregroundColor(driverStat.fullstepsActive ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.stallguardActive ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.overtemp ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.overtempPrewarning ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.shortToGroundA ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.shortToGroundB ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
            }
            VStack {
                Circle()
                    .foregroundColor(driverStat.openLoadA ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.openLoadB ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(driverStat.standstill ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
            }
        }
    }
}

struct BLEStatusDriverStat_Previews: PreviewProvider {
    static var previews: some View {
        let driverStatTest = DriverStatus()
        return BLEStatusDriverStat().environmentObject(driverStatTest)
    }
}
