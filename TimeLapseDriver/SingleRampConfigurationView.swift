//
//  SingleRampConfigurationView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/24/20.
//

import SwiftUI

struct SingleRampConfigurationView: View {
    @EnvironmentObject var stepper: StepperMotor
    @State private var moveBy = "0"
    @State private var position = "0"
    
    var body: some View {
        VStack {
            Text ("\(stepper.name)").font(Font.headline)
            SingleRampDisplayView().environmentObject(stepper.ramp)
            Button(action: {
                SliderCommunicationInterface.shared.setRamp(stepper: self.stepper.code, ramp: self.stepper.ramp)
            }) {
                Text("Update")
            }
            Divider().frame(width: 100, height: 3, alignment: .center)
            TextField("0", text: $moveBy).frame(width: 90, height: nil, alignment: .center)
            HStack{
                Button(action: {
                    let position = Int32(self.position) ?? 0
                    let moveBy = Int32(self.moveBy) ?? 0
                    SliderCommunicationInterface.shared.travelToPosition(stepper: self.stepper.code, position: position-moveBy)
                }) {
                    Text("<")
                }.frame(width: nil, height: nil, alignment: .center)

                Button(action: {
                    SliderCommunicationInterface.shared.stopMotion()
                }) {
                    Text("X")
                }.frame(width: nil, height: nil, alignment: .center)

                Button(action: {
                    let position = Int32(self.position) ?? 0
                    let moveBy = Int32(self.moveBy) ?? 0
                    SliderCommunicationInterface.shared.travelToPosition(stepper: self.stepper.code, position: position+moveBy)
                }) {
                    Text(">")
                }.frame(width: nil, height: nil, alignment: .center)
            }
            Text("Current position:")
            Text("\(self.position)")
                .onReceive(stepper.$position, perform: {
                    self.position = String($0)
                })
        }
    }
}

struct SingleRampConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        let stepper = StepperMotor(code:.slider)
        return SingleRampConfigurationView().environmentObject(stepper)
    }
}
