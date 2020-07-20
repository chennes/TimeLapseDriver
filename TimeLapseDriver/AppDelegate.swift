//
//  AppDelegate.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 4/21/20.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindow: NSWindow!
    var rampWindow: NSWindow!
    var statusWindow: NSWindow!
    var systemStatWindow: NSWindow!
    var keyframeEditorModal: NSWindow!
    var master: MasterController!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        master = MasterController()
        let contentView = ContentView()
            .environmentObject(master)

        // Create the window and set the content view. 
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        mainWindow.center()
        mainWindow.setFrameAutosaveName("Main Window")
        mainWindow.contentView = NSHostingView(rootView: contentView)
        mainWindow.makeKeyAndOrderFront(nil)
        
        showSystemStatus()
    }
    
    func showRampConfiguration() {

        // Create the window and set the content view.
        if rampWindow == nil {
            let contentView = RampConfigurationView()
                .environmentObject(master)
            rampWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            rampWindow.center()
            rampWindow.setFrameAutosaveName("Ramp Configuration")
            rampWindow.contentView = NSHostingView(rootView: contentView)
            rampWindow.isReleasedWhenClosed = false
        }
        rampWindow.makeKeyAndOrderFront(nil)
    }
    
    func showStatusScreen() {

        // Create the window and set the content view.
        if statusWindow == nil {
            let contentView = StatusView()
                .environmentObject(master)
            statusWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            statusWindow.center()
            statusWindow.setFrameAutosaveName("Stepper Status")
            statusWindow.contentView = NSHostingView(rootView: contentView)
            statusWindow.isReleasedWhenClosed = false
        }
        statusWindow.makeKeyAndOrderFront(nil)
    }
    
    func showSystemStatus() {
        if systemStatWindow == nil {
            
            let contentView = BLEStatusSystemStat()
                .environmentObject(SliderCommunicationInterface.shared.bleWrapper!.systemStatus)
            systemStatWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 840),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            systemStatWindow.setFrameAutosaveName("Stepper Status")
            systemStatWindow.contentView = NSHostingView(rootView: contentView)
            systemStatWindow.isReleasedWhenClosed = false
        }
    }
    
    func showConnectionError() {
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func showModalKeyframeEditor(for frame:Keyframe) {
        let contentView = SingleFrameEditorView()
            .environmentObject(frame)
        keyframeEditorModal = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 150),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        keyframeEditorModal.contentView = NSHostingView(rootView: contentView)
        keyframeEditorModal.isReleasedWhenClosed = false
        keyframeEditorModal.makeKeyAndOrderFront(nil)
    }

}

