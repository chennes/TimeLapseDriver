//
//  KeyframeEditView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/6/20.
//

import SwiftUI

struct KeyframeEditView: View {
    @EnvironmentObject var master: MasterController
    
    static var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }
    
    static var secondsFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    
    var body: some View {
        let distance = Binding<Double>(get: { self.master.nextKeyframeD }, set: { self.master.nextKeyframeD = $0; })
        let hours = Binding<Int>(get: { self.master.nextKeyframeH }, set: { self.master.nextKeyframeH = $0; })
        let minutes = Binding<Int>(get: { self.master.nextKeyframeM }, set: { self.master.nextKeyframeM = $0; })
        let seconds = Binding<Double>(get: { self.master.nextKeyframeS }, set: { self.master.nextKeyframeS = $0; })
        return VStack {
            GroupBox(label: Text("Keyframe Creation").font(Font.title)) {
                
                ForEach (self.master.steppers, id: \.id) {stepper in
                    HStack{
                        Text("\(stepper.name)")
                            .frame(width: 50.0, height: nil, alignment: .bottomLeading)
                            .font(Font.headline)
                        StepperControlView(stepper:stepper).environmentObject(self.master)
                    }.frame(minWidth: 450, idealWidth: 500, maxWidth: 10000   , minHeight: nil, idealHeight: nil, maxHeight: nil, alignment: .bottomLeading)
                }
                HStack{
                    Text("Distance to Target").font(Font.headline)
                    TextField("0", value: distance, formatter:KeyframeEditView.integerFormatter).frame(width: 60, height: nil, alignment: .bottomLeading)
                    Text("mm")
                }.frame(minWidth: 450, idealWidth: 500, maxWidth: 10000, minHeight: nil, idealHeight: nil, maxHeight: nil, alignment: .bottomLeading)
                HStack{
                    Text("Time").font(Font.headline)
                    Text("H:").frame(width: 20  , height: nil, alignment: .bottom)
                    TextField("0", value: hours, formatter: KeyframeEditView.integerFormatter).frame(width: 36, height: nil, alignment: .bottomLeading)
                    Text("M:").frame(width: 20  , height: nil, alignment: .bottom)
                    
                    TextField("0", value: minutes, formatter: KeyframeEditView.integerFormatter).frame(width: 36, height: nil, alignment: .bottomLeading)
                    Text("S:").frame(width: 20  , height: nil, alignment: .bottom)
                    
                    TextField("0", value: seconds, formatter: KeyframeEditView.secondsFormatter).frame(width: 36, height: nil, alignment: .bottomLeading)
                    Spacer()
                    Button(action: {
                        var timeInSeconds = Float(self.master.nextKeyframeS)
                        timeInSeconds += (Float(self.master.nextKeyframeM)) * 60
                        timeInSeconds += (Float(self.master.nextKeyframeH)) * 3600
                        
                        self.master.keyframes.append(Keyframe(
                            id: self.master.keyframes.count,
                            time: timeInSeconds,
                            sliderPosition: self.master.steppers[0].position,
                            panPosition: self.master.steppers[1].position,
                            tiltPosition: self.master.steppers[2].position,
                            focusPosition: self.master.steppers[3].position,
                            distanceToTarget: distance.wrappedValue))
                    }) {
                        Text("Add Keyframe")
                    }
                }.frame(minWidth: 500, idealWidth: 500, maxWidth: 10000, minHeight: nil, idealHeight: nil, maxHeight: nil, alignment: .bottomLeading)
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
