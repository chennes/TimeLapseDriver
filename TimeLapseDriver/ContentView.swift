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
    @State private var timelapse: Bool = true
    @State private var releaseBetween: Bool = false
    @State private var numTimelapseFrames: String = "150"
    
    var body: some View {
        VStack{
            VSplitView{
                VStack {
                    GlobalControlView().environmentObject(master)
                    KeyframeEditView().environmentObject(master)
                }.padding(.bottom, 12)
                VStack{
                    List {
                        HStack{
                            Text("#").frame(width: 10, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Time (h:m:s)")
                                .frame(width: 90, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Slider").frame(width: 50, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Pan").frame(width: 50, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Tilt").frame(width: 50, height: nil, alignment: .bottomLeading).font(Font.caption)
                            Text("Focus").frame(width: 50, height: nil, alignment: .bottomLeading).font(Font.caption)
                            if self.timelapse {
                                Text("Seconds per photo").frame(width: 150, height: nil, alignment: .bottomLeading).font(Font.caption)
                            }
                        }
                        ForEach(master.keyframes) { keyframe in
                            HStack{
                                Text("\(keyframe.id)").frame(width: 10, height: nil, alignment: .bottomLeading)
                                Text("\(Int(floor(keyframe.time/3600))):" +
                                     "\(String(format:"%02d",Int(floor(keyframe.time.truncatingRemainder(dividingBy:3600.0)/60)))):" +
                                     "\(String(format:"%.2f",keyframe.time.truncatingRemainder(dividingBy:60.0)))")
                                    .frame(width: 90, height: nil, alignment: .bottomLeading)
                                Text("\(keyframe.sliderPosition!)").frame(width: 50, height: nil, alignment: .bottomLeading)
                                Text("\(keyframe.panPosition!)").frame(width: 50, height: nil, alignment: .bottomLeading)
                                Text("\(keyframe.tiltPosition!)").frame(width: 50, height: nil, alignment: .bottomLeading)
                                Text("\(keyframe.focusPosition!)").frame(width: 50, height: nil, alignment: .bottomLeading)
                                if self.timelapse {
                                    Text("\(keyframe.time / (Float(self.numTimelapseFrames) ?? 1.0))")
                                }
                            }
                        }
                    }
                    HStack{
                        Button(action: {}) {
                        Text("Clear all")
                        }
                        Spacer()
                        Toggle(isOn: $timelapse) {
                            Text("Timelapse")
                        }
                        TextField("150", text: $numTimelapseFrames).frame(width: 70, height: nil, alignment: .bottomLeading).disabled(!timelapse)
                        Text("frames").disabled(!timelapse)
                        Toggle(isOn: $releaseBetween) {
                            Text("Release between frames")
                        }.padding(.trailing, 36).disabled(!timelapse)

                        Button(action: {
                            self.master.numTimelapseFrames = Int(self.numTimelapseFrames) ?? 0
                            self.master.timelapse = self.timelapse
                            self.master.releaseBetweenFrames = self.releaseBetween
                            self.master.run()
                        }) {
                        Text("Run")
                        }
                        Button(action: {SliderSerialInterface.shared.stopMotion()}) {
                        Text("Stop")
                        }
                    }
                }
            }
            }.frame(width: 650, height: 450, alignment: .bottom).padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        master.keyframes.append(Keyframe(id: 1, time: 3665.0, sliderPosition: 1000, panPosition: 500, tiltPosition: 250, focusPosition: 125))
        return ContentView()
            .environmentObject(master)
    }
}
