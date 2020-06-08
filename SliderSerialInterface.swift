//
//  SliderSerialInterface.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 4/21/20.
//
// The slider mechanism, when built on 5/6/2020, had the following stepper characteristics:
// Slide: Positive is from right to left (viewed from behind the camera). 3990 Steps across entire rail.
//
// Tilt: Positive is a tilt down, 1050 single steps to cover complete distance
//
// Pan: Positive is a pan from right to left, counterclockwise from the top. 1965 single steps per complete 360 degree revolution
//
// Focus: Positive direction increases focal distance on Nikons, 422 single steps to cover complete distance on the Rokinon Cine 35mm.
//
// The stepper driver is the Trinamic TMC5041, which uses 256 microsteps per step, driving 200 step/rev steppers, so it takes 51200
// steps to make a single revolution in any motor. The gearing is as follows:
//


import Foundation
import ORSSerial

// Mostly here so I remember to implement them all!
var commandDictionary : [String:String] = [
    "AUTOHOME":"Autohome slider, tilt, and focus. Pan unaffected.",
    "STOP":"Stop current motion, if any.",
    "GO":"Runs all motors at their set maximum velocities until a STOP is received.",
    "GOTO":"Takes four positions, runs the steppers to those positions at their set speed profiles.",
    "SINGLE":"Takes a stepper code and a position, runs that stepper to that position.",
    "PHOTO":"Trigger the IR emitter to mimic the Nikon remote control.",
    "ZERO":"Set the current position as zero (activates braking).",
    "RELEASE":"Release all steppers for manual repositioning. Cancels any homing information.",
    "POSITION":"Query the live motor positions. In microsteps: 51,200 per revolution.",
    "VELOCITY":"Query the live motor velocities.",
    "STATUS":"Query the motor status (holding, running, freewheeling, or homing).",
    "RAMP":"Motor Ramp configuration."
];
//  Motor Ramp configuration commands:
//    First char: S(slide),P(pan),T(tilt),F(focus)
//    Followed by six unsigned integers:
//    1) The acceleration between vStart and v1, range 0...(2^16)-1
//    2) The threshold velocity between a1 and amax, range 0...(2^20)-1
//    3) The acceleration between v1 and vmax, range 0...(2^16)-1
//    4) The target velocity, range 0...(2^23)-512
//    5) The deceleration beetween vmax and v1 (unsigned), range 0...(2^16)-1
//    6) The deceleration between v1 and vStop (unsigned), range 0...(2^16)-1

enum StepperMotorCode:String {
    case slider = "S"
    case pan = "P"
    case tilt = "T"
    case focus = "F"
}

enum StepperState:String {
    case holding = "HOLDING"
    case running = "RUNNING"
    case freewheeling = "FREEWHEELING"
    case homing = "HOMING"
}

final class SliderSerialInterface : NSObject, ObservableObject, ORSSerialPortDelegate {
    static let shared = SliderSerialInterface()
    
    @Published var serialPort: ORSSerialPort? {
        willSet {
            if let port = serialPort {
                port.close()
                port.delegate = nil
            }
        }
        didSet {
            if let port = serialPort {
                port.baudRate = 115200
                port.delegate = self
                port.open()
            }
        }
    }
    @Published var latestResponse: String?

    
    @Published var sliderPosition: Int32 = 0
    @Published var panPosition: Int32 = 0
    @Published var tiltPosition: Int32 = 0
    @Published var focusPosition: Int32 = 0
    
    @Published var sliderSpeed: Int32 = 0
    @Published var panSpeed: Int32 = 0
    @Published var tiltSpeed: Int32 = 0
    @Published var focusSpeed: Int32 = 0
    
    @Published var sliderState: StepperState = .freewheeling
    @Published var panState: StepperState = .freewheeling
    @Published var tiltState: StepperState = .freewheeling
    @Published var focusState: StepperState = .freewheeling
    
    @Published var interrupted: Bool  = false
    @Published var autohoming: Bool  = false
    @Published var running: Bool  = false
    @Published var signaling: Bool  = false
    
    private var timer: Timer?

    let responseDescriptor = ORSSerialPacketDescriptor(prefix: "!".data(using:.ascii), suffix: ";".data(using: .ascii), maximumPacketLength: 128, userInfo: nil)
    let infoPacketDescriptor = ORSSerialPacketDescriptor(prefixString: "|INFO:", suffixString: ";", maximumPacketLength: 128, userInfo: nil)
    let updatePacketDescriptor = ORSSerialPacketDescriptor(prefixString: "|UPDATE:", suffixString: ";", maximumPacketLength: 128, userInfo: nil)
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        latestResponse = "Serial port removed: \(serialPort.description)"
    }
    
        
    private override init () {
        // Figure out where the Arduino is plugged in
        super.init()
        openPort()
    }
    
    deinit {
        serialPort?.close()
    }
    
    /// Instruct the ESP32 to perform a software reset, rebooting. After three seconds, try to resetablish the serial connection.
    func reset() {
        let command = "!RESET;".data(using: .ascii)!
        serialPort?.send(command);
        serialPort?.close()
        
        // Wait three seconds, then try to reconnect...
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false, block: { timer in
            self.openPort();
        })
    }
    
    func reconnect() {
        serialPort?.close()
        openPort()
    }
    
    func openPort () {
        let ports = ORSSerialPortManager.shared().availablePorts
        for port in ports {
            if (port.description.starts(with: "SLAB")) {
                serialPort = port
                serialPort?.delegate = self
                serialPort?.baudRate = 115200
                break
            }
        }
    }
    
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print ("Serial port opened.")
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false, block: { timer in
            self.initializeSlider();
        })
        
        serialPort.startListeningForPackets(matching: updatePacketDescriptor)
        serialPort.startListeningForPackets(matching: infoPacketDescriptor)
    }
    
    func initializeSlider() {
        self.timer = nil
        let command = "!SYN;".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"init"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        print ("Sending initialization command...")
        serialPort?.send(request)
    }
    
    func runCoordinatedMotionToPosition(slider:Int32, pan:Int32, tilt:Int32, focus:Int32) {
        let command = "!M \(slider) \(pan) \(tilt) \(focus);".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command,
                                       userInfo: ["command":"multistep",
                                                  "sliderTarget":slider,
                                                  "panTarget":pan,
                                                  "tiltTarget":tilt,
                                                  "focusTarget":focus],
                                       timeoutInterval: 1.5,
                                       responseDescriptor: responseDescriptor)
        serialPort?.send(request)
        
        // Manually set these right away, they will get push updates from the slider every second or so
        sliderState = .running
        panState = .running
        tiltState = .running
        focusState = .running
    }
    
    func stopMotion() {
        let command = "!STOP;".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"stop"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func setZero() {
        let command = "!ZERO;".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"zero"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func takePhoto() {
        let command = "!PHOTO;".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"photo"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func releaseSteppers() {
        let command = "!RELEASE;".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"release"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func getPosition(stepper:StepperMotorCode) {
        let command = "!POSITION".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"position"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func getVelocity(stepper:StepperMotorCode) {
        let command = "!VELOCITY".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"position"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func getStatus(stepper:StepperMotorCode) {
        let command = "!STATUS".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"position"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func setRamp (stepper:StepperMotorCode, ramp:Ramp) {
        let command = "!RAMP \(stepper.rawValue) \(ramp.a1) \(ramp.v1) \(ramp.amax) \(ramp.vmax) \(ramp.dmax) \(ramp.d1);".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"ramp"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func travelToPosition(stepper:StepperMotorCode, position:Int32) {
        let command = "!SINGLE \(stepper.rawValue) \(position);".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"single"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }
    
    func travelToPosition(slider:Int32,pan:Int32,tilt:Int32,focus:Int32) {
        let command = "!GOTO \(slider) \(pan) \(tilt) \(focus);".data(using: .ascii)!
        let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"goto"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
        serialPort?.send(request)
    }

    func serialPort(_ serialPort: ORSSerialPort,
                    didReceiveResponse responseData: Data,
                    to request: ORSSerialRequest) {
        latestResponse = String(data: responseData, encoding: .ascii) ?? "(Unknown)"
        latestResponse?.removeFirst()
        latestResponse?.removeLast()
        let requestType = (request.userInfo as? Dictionary ?? [:])["command"] ?? "unknown"
        if requestType == "init" {
            if latestResponse != "ACK" {
                print ("Initialization failed")
            } else {
                print ("Initialization complete")
            }
            setRamp(stepper: .slider, ramp: Ramp())
            setRamp(stepper: .pan, ramp: Ramp())
            setRamp(stepper: .tilt, ramp: Ramp())
            setRamp(stepper: .focus, ramp: Ramp())
        } else if requestType == "release" {
            if latestResponse == "RELEASED" {
                print ("Steppers were released")
            } else {
                print ("Release failed: response \(latestResponse!)")
            }
        } else if requestType == "stop" {
            if latestResponse!.starts(with: "OK") {
                print ("Steppers stopped")
                
                sliderState = .holding
                panState = .holding
                tiltState = .holding
                focusState = .holding
            } else {
                print ("Stop failed: response \(latestResponse!)")
            }
        }
    }

    func serialPort(_ serialPort: ORSSerialPort, requestDidTimeout request: ORSSerialRequest) {
        print ("Command timed out.")
        latestResponse = "(Timed out)"
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        latestResponse = "Received \"\(String(data: data, encoding: .ascii) ?? "**")\""
        //print (latestResponse ?? "\0")
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print ("Got an error: \(error.localizedDescription)")
        latestResponse = "ERROR: \(error.localizedDescription)"
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        latestResponse = "Received a packet"
        if let dataAsString = String(data: packetData, encoding: String.Encoding.ascii) {
            if descriptor == infoPacketDescriptor {
                let splitIndex = dataAsString.firstIndex(of: ":") ?? dataAsString.endIndex
                let valueString = dataAsString[dataAsString.index(after: splitIndex)..<dataAsString.endIndex]
                print ("Info from slider: \(valueString)")
            } else if descriptor == updatePacketDescriptor {
                let splitIndex = dataAsString.firstIndex(of: ":") ?? dataAsString.endIndex
                let valueString = dataAsString[dataAsString.index(after: splitIndex)..<dataAsString.endIndex]
                if valueString.starts(with: "DONE") {
                    print ("The steppers have reported completion of the last requested move.")
                    sliderState = .holding
                    panState = .holding
                    tiltState = .holding
                    focusState = .holding
                } else if valueString.starts(with: "POS") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    sliderPosition = Int32(split[1]) ?? 0
                    panPosition = Int32(split[2]) ?? 0
                    tiltPosition = Int32(split[3]) ?? 0
                    focusPosition = Int32(split[4]) ?? 0
                } else if valueString.starts(with: "VEL") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    sliderSpeed = Int32(split[1]) ?? 0
                    panSpeed = Int32(split[2]) ?? 0
                    tiltSpeed = Int32(split[3]) ?? 0
                    focusSpeed = Int32(split[4]) ?? 0
                } else if valueString.starts(with: "STATE") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    sliderState = StepperState(rawValue: String(split[1])) ?? StepperState.freewheeling
                    panState = StepperState(rawValue: String(split[2])) ?? StepperState.freewheeling
                    tiltState = StepperState(rawValue: String(split[3])) ?? StepperState.freewheeling
                    focusState = StepperState(rawValue: String(split[4])) ?? StepperState.freewheeling
                    
                } else if valueString.starts(with: "IARS") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    interrupted = split[1] == "1"
                    autohoming = split[2] == "1"
                    running = split[3] == "1"
                    signaling = split[4] == "1"
                } else {
                    print ("Unrecognized string received \(valueString)")
                }
            }
        }
    }
    
}
