//
//  GlobalControlView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/9/20.
//

import SwiftUI

struct GlobalControlView: View {
    @EnvironmentObject var master: MasterController
    @State private var connectionStatus: String = ""
    @State private var info: String = ""
    @State private var error: String = ""

    var body: some View {
        let liveMode = Binding<Bool>(get: { self.master.liveMode }, set: { self.master.liveMode = $0; })
        let connectVia = Binding<Int>(get: {SliderCommunicationInterface.shared.connectVia.rawValue}, set: {SliderCommunicationInterface.shared.connectVia = ConnectionType(rawValue: $0)!})
        return GroupBox(label: Text("Stepper Control").font(Font.title)) {
            VStack{
                Text("Connection status: \(connectionStatus)")
                    .onReceive(SliderCommunicationInterface.shared.$connectionStatus, perform: {
                        self.connectionStatus = $0
                    })
                Picker(selection: connectVia, label: Text("Connect via:")) {
                        Text("None").tag(0)
                        Text("USB").tag(1)
                        Text("Bluetooth").tag(2)
                    }.frame(width: 200, height: nil, alignment: .center)
//                if connectVia.wrappedValue == 2 {
//                    Text("Info: \(info), Error: \(error)")
//                    .onReceive(SliderCommunicationInterface.shared.$info, perform: {
//                        self.info = $0
//                    })
//                    .onReceive(SliderCommunicationInterface.shared.$error, perform: {
//                        self.error = $0
//                    })
//                }
                HStack{
                    Button(action: {SliderCommunicationInterface.shared.reset()}) {Text("Reset")}
                    Button(action: {SliderCommunicationInterface.shared.reconnect()}) {Text("Reconnect")}
                    Button(action: {SliderCommunicationInterface.shared.takePhoto()}) {Text("Take Photo")}
                    Button(action: {SliderCommunicationInterface.shared.releaseSteppers()}) {Text("Release Steppers")}
                }
                HStack{
                    Button(action: {SliderCommunicationInterface.shared.setZero()}) {Text("Zero and Lock")}
                    Button(action: {
                        let appDelegate = NSApplication.shared.delegate as? AppDelegate?
                        appDelegate??.showRampConfiguration()
                    }) {Text("Configure Ramps")}
                    Button(action: {
                        let appDelegate = NSApplication.shared.delegate as? AppDelegate?
                        appDelegate??.showStatusScreen()
                    }) {Text("Status")}
                    Button(action: {self.master.returnToZero()}) {Text("Return to Zero")}
                }
                Toggle(isOn: liveMode) {
                Text("Live mode (joystick control)")
                }
            }
        }
    }
}

struct GlobalControlView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        return GlobalControlView().environmentObject(master)
    }
}
