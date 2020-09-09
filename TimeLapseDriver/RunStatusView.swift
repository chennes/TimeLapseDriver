//
//  RunStatusView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 9/9/20.
//

import SwiftUI


struct RunStatusView: View {
    @EnvironmentObject var master: MasterController
    var body: some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        let intervalFormatter = DateComponentsFormatter()
        intervalFormatter.unitsStyle = .full
        intervalFormatter.includesApproximationPhrase = true
        intervalFormatter.includesTimeRemainingPhrase = true
        intervalFormatter.allowedUnits = [.minute]
        
        let endTime = master.eta
        let now = Date()
        
        return GroupBox(label: Text("Run Status").font(Font.title)) {
            VStack {
                if master.timelapse {
                    Text("Running timelapse...")
                    Text("Frame \(master.currentTimelapseFrame) of \(master.numTimelapseFrames)")
                    Text("Time between frames: \(master.timeBetweenFrames) seconds")
                    Text("Completion time: \( dateFormatter.string(from:master.eta) ) (\(intervalFormatter.string(from: now, to:endTime)!))")
                    Text("Next frame in \(master.timeToNextFrame) seconds")
                } else {
                    Text("Running continuous...")
                }
            }
        }
    }
}

struct RunStatusView_Previews: PreviewProvider {
    static var previews: some View {
        let master = MasterController()
        return RunStatusView()
        .environmentObject(master)
    }
}
