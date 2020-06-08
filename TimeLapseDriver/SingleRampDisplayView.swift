//
//  SingleRampDisplayView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 5/25/20.
//

import SwiftUI

struct SingleRampDisplayView: View {
    @EnvironmentObject var ramp: Ramp
    @State private var a1: String = "1000"
    @State private var v1: String = "5000"
    @State private var amax: String = "2000"
    @State private var vmax: String = "51200"
    @State private var dmax: String = "2000"
    @State private var d1: String = "5000"
    var body: some View {
        VStack {
            HStack {
                (Text("a") + Text("1")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", text: self.$a1)
                    .onReceive(self.ramp.$a1, perform: {
                        self.a1 = String($0)
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("v") + Text("1")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", text: self.$v1)
                    .onReceive(self.ramp.$v1, perform: {
                        self.v1 = String($0)
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("a") + Text("max")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", text: self.$amax)
                    .onReceive(self.ramp.$amax, perform: {
                        self.amax = String($0)
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("v") + Text("max")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", text: self.$vmax)
                    .onReceive(self.ramp.$vmax, perform: {
                        self.vmax = String($0)
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("d") + Text("max")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", text: self.$dmax)
                    .onReceive(self.ramp.$dmax, perform: {
                        self.dmax = String($0)
                    })
                    .frame(width: 80, height: nil, alignment: .bottomLeading)
            }
            HStack {
                (Text("d") + Text("1")
                    .font(.system(size: 8.0))
                    .baselineOffset(-6.0)).frame(width: 25, height: nil, alignment: .bottomLeading)
                TextField("1000", text: self.$d1)
                    .onReceive(self.ramp.$d1, perform: {
                        self.d1 = String($0)
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
