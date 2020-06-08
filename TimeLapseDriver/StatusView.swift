//
//  StatusView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/8/20.
//

import SwiftUI

struct StatusView: View {
    @EnvironmentObject var master: MasterController
    @State private var interrupted: Bool = false
    @State private var autohoming: Bool = false
    @State private var running: Bool = false
    @State private var signaling: Bool = false
    var body: some View {
        VStack {
            HStack {
                ForEach(master.steppers, id: \.id) {stepper in
                    SingleStepperStatusView().environmentObject(stepper)
                }
            }
            Divider()
            HStack {
                Toggle(isOn: $interrupted) {
                    Text("Interrupted")
                }
                    .onReceive(SliderSerialInterface.shared.$interrupted, perform: {
                        self.interrupted = $0
                    })
                Toggle(isOn: $autohoming) {
                    Text("Autohoming")
                }
                .onReceive(SliderSerialInterface.shared.$autohoming, perform: {
                    self.autohoming = $0
                })
                Toggle(isOn: $running) {
                    Text("Running")
                }
                .onReceive(SliderSerialInterface.shared.$running, perform: {
                    self.running = $0
                })
                Toggle(isOn: $signaling) {
                    Text("Signaling")
                }
                .onReceive(SliderSerialInterface.shared.$signaling, perform: {
                    self.signaling = $0
                })
            }
        }
    }
}

struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        return StatusView().environmentObject(master)
    }
}
