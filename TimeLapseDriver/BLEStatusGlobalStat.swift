//
//  BLEStatusGlobalStat.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/29/20.
//

import SwiftUI
//
//   @Published var reset: Bool = false
//   @Published var driver1Error: Bool = false
//   @Published var driver2Error: Bool = false
//   @Published var chargePumpUndervoltage: Bool = false

struct BLEStatusGlobalStat: View {
    @EnvironmentObject var globalStat: GlobalStatus
    var body: some View {
        VStack {
            Circle()
                .foregroundColor(globalStat.reset ? Color.red : Color.green)
                .frame(width: 12, height: 16, alignment: .center)
            Circle()
                .foregroundColor(globalStat.driver1Error ? Color.red : Color.green)
                .frame(width: 12, height: 16, alignment: .center)
            Circle()
                .foregroundColor(globalStat.driver2Error ? Color.red : Color.green)
                .frame(width: 12, height: 16, alignment: .center)
            Circle()
                .foregroundColor(globalStat.chargePumpUndervoltage ? Color.red : Color.green)
                .frame(width: 12, height: 16, alignment: .center)

        }
    }
}

struct BLEStatusGlobalStat_Previews: PreviewProvider {
    static var previews: some View {
        let globalStatTest = GlobalStatus()
        return BLEStatusGlobalStat().environmentObject(globalStatTest)
    }
}
