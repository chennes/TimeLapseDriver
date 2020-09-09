//
//  ContentView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/6/20.
//

import SwiftUI

struct KeyEventHandling: NSViewRepresentable {
    class KeyView: NSView {
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            super.keyDown(with: event)
            print(">> key \(event.charactersIgnoringModifiers ?? "")")
        }
    }

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        DispatchQueue.main.async { // wait till next event cycle
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}

struct ContentView: View {
    @EnvironmentObject var master: MasterController
    @State private var showModalEditor = false
    
    static var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }
    
    var body: some View {
        let timelapse = Binding<Bool>(get: {self.master.timelapse}, set: {self.master.timelapse = $0})
        let numTimelapseFrames = Binding<Int>(get: {self.master.numTimelapseFrames}, set: {self.master.numTimelapseFrames = $0})
        return VStack{
            VSplitView{
                VStack {
                    if master.currentState != .idle && master.currentState != .live {
                        RunStatusView().environmentObject(master)
                    } else {
                        GlobalControlView().environmentObject(master)
                    }
                    KeyframeEditView().environmentObject(master)
                }.padding(.bottom, 12)
                VStack{
                    List {
                        HStack{
                            Text("#").frame(width: 10, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Time (h:m:s)")
                                .frame(width: 90, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Target").frame(width: 50, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Slider").frame(width: 70, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Pan").frame(width: 70, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Tilt").frame(width: 70, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Focus").frame(width: 70, height: nil, alignment: .bottomLeading).font(Font.caption)
                        }
                        ForEach(master.keyframes) { keyframe in
                            KeyframeRowView().environmentObject(keyframe)
                        }
                    }
                    HStack{
                        Button(action: {
                            self.master.keyframes.removeAll()
                        }) {
                        Text("Clear all")
                        }
                        Spacer()
                        Toggle(isOn: timelapse) {
                            Text("Timelapse")
                        }
                        TextField("150", value: numTimelapseFrames, formatter: ContentView.integerFormatter).frame(width: 70, height: nil, alignment: .bottomLeading).disabled(!timelapse.wrappedValue)
                        Text("frames").disabled(!timelapse.wrappedValue)

                        Button(action: {
                            self.master.run()
                        }) {
                        Text("Run")
                        }
                        Button(action: {
                            SliderCommunicationInterface.shared.stopMotion()
                            self.master.cancel()
                        }) {
                        Text("Stop")
                        }
                    }
                }
            }
            }.frame(width: 500  , height: 590, alignment: .bottom).padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        master.keyframes.append(Keyframe(id: 1, time: 3665.0, sliderPosition: 1000000, panPosition: 50000, tiltPosition: 25000, focusPosition: 12500, distanceToTarget: 0))
        return ContentView()
            .environmentObject(master)
    }
}
