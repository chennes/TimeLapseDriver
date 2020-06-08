//
//  GlobalControlView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/9/20.
//

import SwiftUI

struct GlobalControlView: View {
    @EnvironmentObject var master: MasterController
    var body: some View {
        GroupBox(label: Text("Stepper Control").font(Font.title)) {
            VStack{
                HStack{
                    Button(action: {SliderSerialInterface.shared.reset()}) {Text("Reset")}
                    Button(action: {SliderSerialInterface.shared.reconnect()}) {Text("Reconnect")}
                    Button(action: {SliderSerialInterface.shared.takePhoto()}) {Text("Take Photo")}
                    Button(action: {SliderSerialInterface.shared.releaseSteppers()}) {Text("Release Steppers")}
                }
                HStack{
                    Button(action: {SliderSerialInterface.shared.setZero()}) {Text("Zero and Lock")}
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
