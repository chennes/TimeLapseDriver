//
//  KeyframeEditView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/6/20.
//

import SwiftUI

struct KeyframeEditView: View {
    @EnvironmentObject var master: MasterController
    @State var hours: String = "0"
    @State var minutes: String = "0"
    @State var seconds: String = "0.0"
    
    var body: some View {
        VStack {
            GroupBox(label: Text("Keyframe Creation").font(Font.title)) {
                
                ForEach (self.master.steppers, id: \.id) {stepper in
                    HStack{
                        Text("\(stepper.name)")
                            .frame(width: 50.0, height: nil, alignment: .bottomLeading)
                            .font(Font.headline)
                        StepperControlView(stepper:stepper).environmentObject(self.master)
                    }
                }
            }
            HStack{
                Spacer()
                HStack{
                    Text("Time: ").padding(3).font(Font.subheadline.bold())
                    Text("H:")
                    TextField("0", text: $hours).frame(width: 36, height: nil, alignment: .bottomLeading)
                    Text("M:")
                    TextField("0", text: $minutes).frame(width: 36, height: nil, alignment: .bottomLeading)
                    Text("S:")
                    TextField("0", text: $seconds).frame(width: 54, height: nil, alignment: .bottomLeading)
                    Button(action: {
                        var timeInSeconds = Float(self.seconds) ?? 0
                        timeInSeconds += (Float(self.minutes) ?? 0) * 60
                        timeInSeconds += (Float(self.hours) ?? 0) * 3600
                        
                        self.master.keyframes.append(Keyframe(
                            id: self.master.keyframes.count,
                            time: timeInSeconds,
                            sliderPosition: self.master.steppers[0].position,
                            panPosition: self.master.steppers[1].position,
                            tiltPosition: self.master.steppers[2].position,
                            focusPosition: self.master.steppers[3].position))
                    }) {
                        Text("Add Keyframe")
                    }
                }

            }
        }
    }
}

struct KeyframeEditView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        return KeyframeEditView().environmentObject(master)
    }
}
