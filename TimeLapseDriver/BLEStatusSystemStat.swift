//
//  BLEStatusSystemStat.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/29/20.
//

import SwiftUI

struct BLEStatusSystemStat: View {
    @EnvironmentObject var systemStat:SystemStatus
    var body: some View {
        HStack {
            VStack {
                Spacer().frame(width: nil, height: 125, alignment: .topTrailing)
                VStack {
                    Text ("Stallguard").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("CS Actual").frame(width:140,height: 29, alignment: .topTrailing)
                    Text ("Fullstep Active?").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Stallguard Status").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Overtemp").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Overtemp prewarning").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Short to ground A").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Short to ground B").frame(width:140,height: 24, alignment: .topTrailing)
                }
                VStack {
                    Text ("Open Load A").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Open Load B").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Standstill?").frame(width:140,height: 24, alignment: .topTrailing)
                }
                
                Spacer().frame(width: nil, height: 26, alignment: .topTrailing)
                VStack {
                    Text ("Status Stop Left").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Status Stop Right").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Status Latch Left").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Status Latch Right").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Event Stop Left").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Event Stop Right").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Event Stop Stallguard").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Event Pos Reached").frame(width:140,height: 24, alignment: .topTrailing)
                }
                
                VStack {
                    Text ("Velocity Reached").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Position Reached").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Velocity is Zero").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("tZeroWait Active").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Second Move").frame(width:140,height: 24, alignment: .topTrailing)
                    Text ("Stallguard Status").frame(width:140,height: 24, alignment: .topTrailing)
                }
            }.frame(width:nil,height: 750, alignment: .topTrailing)
            BLEStatusBoardStat().environmentObject(systemStat.boardStatus[0])
            BLEStatusBoardStat().environmentObject(systemStat.boardStatus[1])
        }.padding()
    }
}

struct BLEStatusSystemStat_Previews: PreviewProvider {
    static var previews: some View {
        let systemStatTest = SystemStatus()
        return BLEStatusSystemStat().environmentObject(systemStatTest)
    }
}
