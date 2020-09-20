//
//  SliderCommunicationInterface.swift
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
import Combine
import ORSSerial
import CoreBluetooth

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

enum ConnectionType:Int {
    case none = 0
    case usb = 1
    case bluetooth = 2
}

enum StepperMotorCode:UInt8 {
    case slider = 0x00
    case pan = 0x01
    case tilt = 0x02
    case focus = 0x03
}

enum StepperState:UInt8 {
    case holding = 1
    case running = 2
    case freewheeling = 3
    case homingup = 4
    case homingdown = 5
    case homingreturn = 6
}

extension Notification.Name {
    static let didInitializeSlider = Notification.Name("didInitializeSlider")
    static let failedToOpenPort = Notification.Name("failedToOpenPort")
}

final class SliderCommunicationInterface : NSObject, ObservableObject, ORSSerialPortDelegate {
    
    static let shared = SliderCommunicationInterface()
    
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
    var bleWrapper:BLEWrapper? = nil
    @Published var latestResponse: String?
    @Published var connectionStatus: String = "No connection selected"
    @Published var bleIsConnected: Bool = false {
        didSet {
            if bleIsConnected {
                print ("Bluetooth is now available for communications.")
            } else {
                print ("Bluetooth is not available.")
            }
        }
    }
    @Published var usbIsConnected: Bool = false {
           didSet {
               if usbIsConnected {
                   print ("USB is now available for communications.")
               } else {
                   print ("USB is not available.")
               }
           }
       }
    @Published var connectVia:ConnectionType = .none {
        didSet {
            if connectVia == .usb && !usbIsConnected {
                connectVia = .none
                connectionStatus = "No USB connection available."
            }
            if connectVia == .bluetooth && !bleIsConnected {
                connectVia = .none
                connectionStatus = "No Bluetooth connection available."
            }
            if connectVia == .bluetooth {
                createBLESubscriptions()
            } else {
                for subscription in bleInfoSubscriptions {
                    subscription?.cancel()
                }
                bleInfoSubscriptions.removeAll()
            }
            
            if connectVia == .usb {
                serialPort?.startListeningForPackets(matching: updatePacketDescriptor)
                serialPort?.startListeningForPackets(matching: infoPacketDescriptor)
            } else {
                serialPort?.stopListeningForPackets(matching: updatePacketDescriptor)
                serialPort?.stopListeningForPackets(matching: infoPacketDescriptor)
            }
            initializeSlider()
            switch connectVia {
            case .none:
                print ("No connection")
            case .usb:
                connectionStatus = "Connecting via USB"
            case .bluetooth:
                connectionStatus = "Connecting via Bluetooth"
            }
        }
    }
    private var bleAvailabilitySubscription: AnyCancellable?
    private var bleInfoSubscriptions:[AnyCancellable?] = []
    private var oldConnectVia:ConnectionType?

    var position:[Int32] = [0,0,0,0]
    private(set) var positionPublisher:[ CurrentValueSubject<Int32, Never> ]
    
    var velocity:[Int32] = [0,0,0,0]
    private(set) var velocityPublisher:[ CurrentValueSubject<Int32, Never> ]
    
    var state:[UInt8] = [0,0,0,0]
    private(set) var statePublisher:[ CurrentValueSubject<UInt8, Never> ]
    
    @Published var info:String = ""
    @Published var error:String = ""
    
    @Published var interrupted: Bool  = false
    @Published var autohoming: Bool  = false
    @Published var running: Bool  = false
    @Published var signaling: Bool  = false
    
    private var timer: Timer?

    let responseDescriptor = ORSSerialPacketDescriptor(prefix: "!".data(using:.ascii), suffix: ";".data(using: .ascii), maximumPacketLength: 128, userInfo: nil)
    let infoPacketDescriptor = ORSSerialPacketDescriptor(prefixString: "|INFO:", suffixString: ";", maximumPacketLength: 128, userInfo: nil)
    let updatePacketDescriptor = ORSSerialPacketDescriptor(prefixString: "|UPDATE:", suffixString: ";", maximumPacketLength: 128, userInfo: nil)

    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        if serialPort == self.serialPort {
            connectionStatus = "Serial port lost. Attempting to switch to Bluetooth."
            self.serialPort = nil
            usbIsConnected = false
            if connectVia == .usb {
                if bleIsConnected {
                    connectVia = .bluetooth
                    createBLESubscriptions()
                    
                } else {
                    connectVia = .none
                }
            }
        }
        latestResponse = "Serial port removed: \(serialPort.description)"
    }
    
    fileprivate func createBLESubscriptions () {
        bleInfoSubscriptions.append(bleWrapper?.$info.assign(to: \SliderCommunicationInterface.info, on: self))
        bleInfoSubscriptions.append(bleWrapper?.$error.assign(to: \SliderCommunicationInterface.error, on: self))
        for code in 0 ..< 4 {
            bleInfoSubscriptions.append(bleWrapper?.positionPublisher[code].sink(receiveValue: { (value:Int32) in
                self.positionPublisher[code].value = value
            }))
                
            bleInfoSubscriptions.append(bleWrapper?.velocityPublisher[code].sink(receiveValue: { (value:Int32) in
                self.velocityPublisher[code].value = value
            }))
                
            bleInfoSubscriptions.append(bleWrapper?.statePublisher[code].sink(receiveValue: { (value:UInt8) in
                self.statePublisher[code].value = value
            }))
        }
    }
    
    fileprivate func destroyBLESubscriptions() {

        for subscription in bleInfoSubscriptions {
            subscription?.cancel()
        }
        bleInfoSubscriptions.removeAll()
    }
    
    private override init () {
        positionPublisher = [ CurrentValueSubject<Int32, Never>(position[0]),
                              CurrentValueSubject<Int32, Never>(position[1]),
                              CurrentValueSubject<Int32, Never>(position[2]),
                              CurrentValueSubject<Int32, Never>(position[3]) ]
        
        velocityPublisher = [ CurrentValueSubject<Int32, Never>(velocity[0]),
                              CurrentValueSubject<Int32, Never>(velocity[1]),
                              CurrentValueSubject<Int32, Never>(velocity[2]),
                              CurrentValueSubject<Int32, Never>(velocity[3]) ]
        
        statePublisher = [ CurrentValueSubject<UInt8, Never>(state[0]),
                           CurrentValueSubject<UInt8, Never>(state[1]),
                           CurrentValueSubject<UInt8, Never>(state[2]),
                           CurrentValueSubject<UInt8, Never>(state[3]) ]
        super.init()
        
        
        bleWrapper = BLEWrapper()
        bleAvailabilitySubscription = bleWrapper?.$connected.assign(to: \SliderCommunicationInterface.bleIsConnected, on: self)
        openPort()
    }
    
    deinit {
        if connectVia == .usb {
            let command = "!RESET;".data(using: .ascii)!
            serialPort?.send(command);
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .reset)
        } else {
            print ("Dummy call: RESET")
        }
    }
    
    /// Instruct the ESP32 to perform a software reset, rebooting. After three seconds, try to resetablish the serial connection.
    func reset() {
        oldConnectVia = connectVia
        if connectVia == .usb {
            let command = "!RESET;".data(using: .ascii)!
            serialPort?.send(command);
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .reset)
        } else {
            print ("Dummy call: RESET")
        }
        connectionStatus = "ESP32 is resetting"
        // Wait a tenth of a second for any response from the system, then disconnect
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { timer in
            self.postReset();
        })
    }
    
    func postReset() {
        serialPort?.close()
        connectVia = .none
        connectionStatus = "Waiting to reconnect"
        // Wait five seconds, then try to reconnect...
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false, block: { timer in
            self.openPort();
            self.bleWrapper = BLEWrapper()
        })
    }
    
    func reconnect() {
        connectionStatus = "Opening port"
        serialPort?.close()
        openPort()
        bleWrapper = BLEWrapper()
    }
    
    func openPort () {
        let ports = ORSSerialPortManager.shared().availablePorts
        var usbConnection:ORSSerialPort?
        for port in ports {
            if (port.description.starts(with: "SLAB")) {
                usbConnection = port
                serialPort = usbConnection!
                serialPort?.baudRate = 115200
                serialPort?.delegate = self
            }
        }
        if serialPort == nil {
            connectionStatus = ""
        }
    }
    
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        usbIsConnected = true
        if oldConnectVia != nil {
            connectVia = oldConnectVia!
            oldConnectVia = nil
        }
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false, block: { timer in
            self.connectionStatus = "Ready to connect."
        })
        if connectVia == .usb {
            serialPort.startListeningForPackets(matching: updatePacketDescriptor)
            serialPort.startListeningForPackets(matching: infoPacketDescriptor)
        }
    }
    
    func initializeSlider() {
        self.timer = nil
        if connectVia == .usb {
            let command = "!SYN;".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"init"], timeoutInterval: 3.0, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .synchronize)
        } else {
            print ("Dummy call: SYNCHRONIZE")
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
            NotificationCenter.default.post(.init(name: .didInitializeSlider))
            self.connectionStatus = "Initialization complete."
        })
        print ("Sending initialization command...")
    }
    
    func stopMotion() {
        if connectVia == .usb {
            let command = "!STOP;".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"stop"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .stop)
        } else {
            print ("Dummy call: STOP")
        }
    }
    
    func setZero() {
        if connectVia == .usb {
            let command = "!ZERO;".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"zero"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .zero)
        } else {
            for i in 0..<4 {
                self.positionPublisher[i].value = 0
            }
            print ("Dummy call: ZERO")
        }
    }
    
    func takePhoto() {
        if connectVia == .usb {
            let command = "!PHOTO;".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"photo"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .photo)
        } else {
            print ("Dummy call: PHOTO")
        }
    }
    
    func releaseSteppers() {
        if connectVia == .usb {
            let command = "!RELEASE;".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"release"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .release)
        } else {
            print ("Dummy call: RELEASE")
        }
    }
    
    func getPosition(stepper:StepperMotorCode) {
        if connectVia == .usb {
            let command = "!POSITION".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"position"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .position)
        } else {
            print ("Dummy call: POSITION")
        }
    }
    
    func getVelocity(stepper:StepperMotorCode) {
        if connectVia == .usb {
            let command = "!VELOCITY".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"velocity"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .velocity)
        } else {
            print ("Dummy call: VELOCITY")
        }
    }
    
    func getStatus(stepper:StepperMotorCode) {
        if connectVia == .usb {
            let command = "!STATUS".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"status"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .status)
        } else {
            print ("Dummy call: STATUS")
        }
    }
    
    func setRamp (stepper:StepperMotorCode, ramp:Ramp) {
        if connectVia == .usb {
            let command = "!RAMP \(stepper.rawValue) \(ramp.a1) \(ramp.v1) \(ramp.amax) \(ramp.vmax) \(ramp.dmax) \(ramp.d1);".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"ramp","stepper":stepper.rawValue], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            let charCode = stepper.rawValue
            let rampData:[UInt32] = [ramp.a1,ramp.v1, ramp.amax, ramp.vmax, ramp.dmax, ramp.d1]
            bleWrapper?.sendCommand(command: .ramp, motorCode: charCode, parameters:rampData)
        } else {
            print ("Dummy call: RAMP")
        }
    }
    
    func travelToPosition(stepper:StepperMotorCode, position:Int32) {
        if connectVia == .usb {
            let command = "!SINGLE \(stepper.rawValue) \(position);".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"single"], timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .single, motorCode: stepper.rawValue, parameters: [position])
        } else {
            print ("Dummy call: SINGLE")
            self.positionPublisher[Int(stepper.rawValue)].value = position
        }
    }
    
    func runAtSpeed(velocity:[Int32]) {
        if connectVia == .usb {
            // This probably needs to run at a very low timeout.
            let command = "!GO \(velocity[0]) \(velocity[1]) \(velocity[2]) \(velocity[3]);".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"go"],
                                           timeoutInterval: 0.1, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .go, parameters: velocity)
        } else {
            print ("Dummy call: GO")
        }
    }
    
    func travelToPosition(position:[Int32]) {
        if connectVia == .usb {
            let command = "!GOTO \(position[0]) \(position[1]) \(position[2]) \(position[3]);".data(using: .ascii)!
            let request = ORSSerialRequest(dataToSend: command, userInfo: ["command":"goto"],
                                           timeoutInterval: 1.5, responseDescriptor: responseDescriptor)
            serialPort?.send(request)
        } else if connectVia == .bluetooth {
            bleWrapper?.sendCommand(command: .goto, parameters: position)
        } else {
            for i in 0..<4 {
                self.positionPublisher[i].value = position[i]
            }
            print ("Dummy call: GOTO")
        }
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
                NotificationCenter.default.post(.init(name: .didInitializeSlider))
            }
        } else if requestType == "release" {
            if latestResponse == "OK RELEASE" {
                print ("Steppers were released")
            } else {
                print ("Release failed: response \(latestResponse!)")
            }
        } else if requestType == "stop" {
            if latestResponse!.starts(with: "OK") {
                print ("Steppers stopped")
            } else {
                print ("Stop failed: response \(latestResponse!)")
            }
        } else if requestType == "ramp" {
            let stepperName = (request.userInfo as? Dictionary ?? [:])["stepper"] ?? "unknown"
            if latestResponse!.starts(with: "OK") {
                print ("Ramp updated for \(stepperName) stepper")
            } else {
                print ("Failed to update ramp for \(stepperName) stepper")
                print (latestResponse ?? "\0")
            }
        } else if requestType == "goto" {
            if latestResponse!.starts(with: "OK") {
                print ("Motion triggered successfully.")
            } else {
                print ("Problem with motion: \(latestResponse!)")
            }
        } else {
            //print ("Request response: \(latestResponse!)")
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
                } else if valueString.starts(with: "POS") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    for i in 0..<4 {
                        self.positionPublisher[i].value = Int32(split[i+1]) ?? 0
                    }
                } else if valueString.starts(with: "VEL") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    for i in 0..<4 {
                        self.velocityPublisher[i].value = Int32(split[i+1]) ?? 0
                    }
                } else if valueString.starts(with: "STATE") {
                    let split = valueString.split(separator: " ")
                    if split.count < 5 {
                        print ("Unexpected return: got \"\(valueString)\", which isn't five parts")
                        return
                    }
                    
                    for i in 0..<4 {
                        self.statePublisher[i].value = UInt8(split[i+1]) ?? 0
                    }
                    
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
