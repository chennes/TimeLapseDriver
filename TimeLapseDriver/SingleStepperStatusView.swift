//
//  SingleStepperStatusView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/8/20.
//

import SwiftUI

struct SingleStepperStatusView: View {
    @EnvironmentObject var stepper: StepperMotor
    @State private var positionString: String = "0"
    @State private var velocityString: String = "0"
    @State private var stateString: String = "Free"
    var body: some View {
        VStack{
            Text ("\(stepper.name)").font(Font.headline)
            Text("Position").font(Font.caption)
            Text("\(positionString)")
                .onReceive(self.stepper.$position, perform: {
                    self.positionString = String($0)
                })
            Text("Velocity").font(Font.caption)
            Text("\(velocityString)")
                .onReceive(self.stepper.$velocity, perform: {
                    self.velocityString = String($0)
                })
            Text("State").font(Font.caption)
            Text("\(stateString)")
            .onReceive(self.stepper.$state, perform: {
                self.stateString = String($0.rawValue)
            })
        }
    }
}

struct SingleStepperStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let stepper = StepperMotor(code: .slider)
        return SingleStepperStatusView().environmentObject(stepper)
    }
}
