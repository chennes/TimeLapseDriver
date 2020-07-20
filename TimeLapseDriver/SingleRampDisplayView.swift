//
//  SingleRampDisplayView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/25/20.
//

import SwiftUI

struct SingleRampDisplayView: View {
    @EnvironmentObject var ramp: Ramp
    @State private var a1: UInt32 = 1000
    @State private var v1: UInt32 = 5000
    @State private var amax: UInt32 = 2000
    @State private var vmax: UInt32 = 51200
    @State private var dmax: UInt32 = 2000
    @State private var d1: UInt32 = 5000
    
    static var integerFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    
    var body: some View {
        VStack {
            HStack {
                (Text("a") + Text("1")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", value: $a1, formatter: SingleRampDisplayView.integerFormatter, onCommit: {
                    self.ramp.a1   = self.a1
                })
                    .onReceive(self.ramp.$a1, perform: {
                        self.a1 = $0
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("v") + Text("1")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", value: self.$v1, formatter: SingleRampDisplayView.integerFormatter, onCommit: {
                    self.ramp.v1   = self.v1
                })
                    .onReceive(self.ramp.$v1, perform: {
                        self.v1 = $0
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("a") + Text("max")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", value: self.$amax, formatter: SingleRampDisplayView.integerFormatter, onCommit: {
                    self.ramp.amax   = self.amax
                })
                    .onReceive(self.ramp.$amax, perform: {
                        self.amax = $0
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("v") + Text("max")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", value: self.$vmax, formatter: SingleRampDisplayView.integerFormatter, onCommit: {
                    self.ramp.vmax   = self.vmax
                })
                    .onReceive(self.ramp.$vmax, perform: {
                        self.vmax = $0
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("d") + Text("max")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", value: self.$dmax, formatter: SingleRampDisplayView.integerFormatter, onCommit: {
                    self.ramp.dmax   = self.dmax
                })
                    .onReceive(self.ramp.$dmax, perform: {
                        self.dmax = $0
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("d") + Text("1")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", value: self.$d1, formatter: SingleRampDisplayView.integerFormatter, onCommit: {
                    self.ramp.d1   = self.d1
                })
                    .onReceive(self.ramp.$d1, perform: {
                        self.d1 = $0
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            
        }
    }
}
    
struct RampDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        SingleRampDisplayView()
    }
}
