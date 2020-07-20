//
//  BLEStatusBoardStat.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/29/20.
//

import SwiftUI

struct BLEStatusBoardStat: View {
    @EnvironmentObject var boardStat: BoardStatus
    var body: some View {
        VStack {
            HStack {
                VStack{
                    Text("Was Reset").frame(width: 75, height: 24, alignment: .trailing)
                    Text("DRV1 Err").frame(width: 75, height: 24, alignment: .trailing)
                    Text("DRV2 Err").frame(width: 75, height: 24, alignment: .trailing)
                    Text("Undervolt").frame(width: 75, height: 24, alignment: .trailing)
                }
                BLEStatusGlobalStat().environmentObject(boardStat.globalStatus)
            }
            Text("Driver Status")
            HStack {
                BLEStatusDriverStat().environmentObject(boardStat.driverStatus[0])
                BLEStatusDriverStat().environmentObject(boardStat.driverStatus[1])
            }
            Text("Ramp Status")
            HStack {
                BLEStatusRampStat().environmentObject(boardStat.rampStatus[0]) .frame(width: 60, height: nil, alignment: .center)
                BLEStatusRampStat().environmentObject(boardStat.rampStatus[1]) .frame(width: 60, height: nil, alignment: .center)
            }
        }
    }
}

struct BLEStatusBoardStat_Previews: PreviewProvider {
    static var previews: some View {
        let boardStatTest = BoardStatus()
        return BLEStatusBoardStat().environmentObject(boardStatTest)
    }
}
