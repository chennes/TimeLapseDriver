//
//  SingleFrameEditorView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 7/19/20.
//

import SwiftUI

struct SingleFrameEditorView: View {
    @EnvironmentObject var keyframe:Keyframe
    @Environment(\.presentationMode) var presentationMode
    
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
        let time = Binding<Float>(get: { self.keyframe.time }, set: { self.keyframe.time = $0; })
        let distance = Binding<Double>(get: { (self.keyframe.distanceToTarget ?? 0.0) }, set: { self.keyframe.distanceToTarget = $0; })
        let slider = Binding<Int32>(get: { (self.keyframe.sliderPosition ?? 0) }, set: { self.keyframe.sliderPosition = $0; })
        let pan = Binding<Int32>(get: { (self.keyframe.panPosition ?? 0) }, set: { self.keyframe.panPosition = $0; })
        let tilt = Binding<Int32>(get: { (self.keyframe.tiltPosition ?? 0) }, set: { self.keyframe.tiltPosition = $0; })
        let focus = Binding<Int32>(get: { (self.keyframe.focusPosition ?? 0) }, set: { self.keyframe.focusPosition = $0; })
        return VStack {
            HStack {
                VStack {
                    Text("Time")
                    TextField("0", value: time, formatter: SingleFrameEditorView.secondsFormatter)
                }
                VStack {
                    Text("Distance")
                    TextField("0", value: distance, formatter: SingleFrameEditorView.secondsFormatter)
                }
                VStack {
                    Text("Slider")
                    TextField("0", value: slider, formatter: SingleFrameEditorView.integerFormatter)
                }
                VStack {
                    Text("Pan")
                    TextField("0", value: pan, formatter: SingleFrameEditorView.integerFormatter)
                }
                VStack {
                    Text("Tilt")
                    TextField("0", value: tilt, formatter: SingleFrameEditorView.integerFormatter)
                }
                VStack {
                    Text("Focus")
                    TextField("0", value: focus, formatter: SingleFrameEditorView.integerFormatter)
                }
            }
            HStack {
                Button(action: {
                    SliderCommunicationInterface.shared.travelToPosition(position: [slider.wrappedValue, pan.wrappedValue, tilt.wrappedValue, focus.wrappedValue])
                }) {
                Text("Go to this position")
                }
                Button(action: {
                    SliderCommunicationInterface.shared.stopMotion()
                }) {
                Text("Stop")
                }
            }
        }.padding()
    }
}

struct SingleFrameEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let keyframe = Keyframe(id: 0, time: 0.0, sliderPosition: 0, panPosition: 0, tiltPosition: 0, focusPosition: 0, distanceToTarget: 0)
        return SingleFrameEditorView().environmentObject(keyframe)
    }
}
