//
//  RampConfigurationView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/24/20.
//

import SwiftUI

struct RampConfigurationView: View {
    @EnvironmentObject var master: MasterController
    @State var positionStrings:[UUID:String] = [:]
    @State var moveByStrings:[UUID:String] = [:]
    var body: some View {
        HStack {
            ForEach(master.steppers, id: \.id) {stepper in
                VStack {
                    SingleRampConfigurationView().environmentObject(stepper)
                }
            }
        }
    }
}

struct RampConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        return RampConfigurationView().environmentObject(master)
    }
}
