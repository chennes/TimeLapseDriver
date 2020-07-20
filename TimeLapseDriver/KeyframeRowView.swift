//
//  KeyframeRowView.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 7/20/20.
//

import SwiftUI

struct KeyframeRowView: View {
    @EnvironmentObject var keyframe:Keyframe
    var body: some View {
        HStack{
            Text("\(keyframe.id)").frame(width: 10, height: nil, alignment: .bottomLeading)
            Text("\(Int(floor(keyframe.time/3600))):" +
                 "\(String(format:"%02d",Int(floor(keyframe.time.truncatingRemainder(dividingBy:3600.0)/60)))):" +
                 "\(String(format:"%.2f",keyframe.time.truncatingRemainder(dividingBy:60.0)))")
                .frame(width: 90, height: nil, alignment: .bottomLeading)
            Text("\(Int(keyframe.distanceToTarget!))").frame(width: 50, height: nil, alignment: .bottomLeading)
            Text("\(keyframe.sliderPosition!)").frame(width: 70, height: nil, alignment: .bottomLeading)
            Text("\(keyframe.panPosition!)").frame(width: 70, height: nil, alignment: .bottomLeading)
            Text("\(keyframe.tiltPosition!)").frame(width: 70, height: nil, alignment: .bottomLeading)
            Text("\(keyframe.focusPosition!)").frame(width: 70, height: nil, alignment: .bottomLeading)
        }.onTapGesture(count: 2, perform: {
            let appDelegate = NSApplication.shared.delegate as? AppDelegate?
            appDelegate??.showModalKeyframeEditor(for:self.keyframe)
        })    }
}

struct KeyframeRowView_Previews: PreviewProvider {
    static var previews: some View {
        let keyframe = Keyframe(id: 0, time: 0, sliderPosition: 0, panPosition: 0, tiltPosition: 0, focusPosition: 0, distanceToTarget: 0)
        return KeyframeRowView().environmentObject(keyframe)
    }
}
