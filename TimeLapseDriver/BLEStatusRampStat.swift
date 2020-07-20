//
//  BLEStatusRampStat.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/29/20.
//

import SwiftUI

struct BLEStatusRampStat: View {
    @EnvironmentObject var rampStat:RampStatus
    var body: some View {
        VStack {

            VStack {
                Circle()
                    .foregroundColor(rampStat.statusStopLeft ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.statusStopRight ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.statusLatchLeft ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.statusLatchRight ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.eventStopLeft ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.eventStopRight ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.eventStopStallguard ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.eventPositionReached ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
            }
            VStack {
                Circle()
                    .foregroundColor(rampStat.velocityReached ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.positionReached ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.velocityIsZero ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.tZeroWaitActive ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.secondMove ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
                Circle()
                    .foregroundColor(rampStat.stallguardStatus ? Color.red : Color.green)
                    .frame(width: 12, height: 16, alignment: .center)
            }
        }
    }
}

struct BLEStatusRampStat_Previews: PreviewProvider {
    static var previews: some View {
        let rampStatTest = RampStatus()
        return BLEStatusRampStat().environmentObject(rampStatTest)
    }
}
