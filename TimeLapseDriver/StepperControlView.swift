//
//  StepperControlView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/7/20.
//

import SwiftUI

struct StepperControlView: View {
    @EnvironmentObject var master: MasterController
    @State private var move: String = "51200"
    @State private var positionString: String = "0"
    
    let stepper:StepperMotor
    
    var body: some View {
        HStack {
            Text("Move by:")
                .frame(width: 55.0, height: nil, alignment: .bottomLeading)
            TextField("100.0", text: $move)
                .frame(width: 72.0, height: nil, alignment: .bottomLeading)
            Button(action: {
                self.stepper.target = Int32(self.stepper.position + (Int32(self.move) ?? 0))
                SliderSerialInterface.shared.travelToPosition(stepper: self.stepper.code,position: self.stepper.target)
            }) {
                Text("Go")
            }.frame(width: 72.0, height: nil, alignment: .bottomLeading)
            Text("Current position: ")
                .frame(width: 105.0, height: nil, alignment: .bottomLeading)
            Text("\(positionString)")
                .onReceive(self.stepper.$position, perform: {
                    self.positionString = String($0)
                })
                .frame(width: 90.0, height: nil, alignment: .bottomLeading)
        }
    }
}

struct StepperControlView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        return StepperControlView(stepper: master.steppers.first!).environmentObject(master)
    }
}
