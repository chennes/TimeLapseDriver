//
//  TimelapseMonitorView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/9/20.
//

import SwiftUI

struct TimelapseMonitorView: View {
    var body: some View {
        VStack{
            Text("Total number of frames:")
            Text("Current frame:")
            Text("Time between frames:")
            Text("Time remaining:")
            Text("Expected completion time:")
            HStack{
                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/) {
                    Text("Cancel")
                }
                Button(action: /*@START_MENU_TOKEN@*/{}/*@END_MENU_TOKEN@*/) {
                    Text("Pause")
                }
            }
        }
    }
}

struct TimelapseMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        TimelapseMonitorView()
    }
}
