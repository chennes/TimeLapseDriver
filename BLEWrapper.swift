//
//  BLEWrapper.swift
//  TimeLapseDriver
//
//  Created by Chris Hennes on 6/12/20.
//
// This wrapper is designed to make a Bluetooth Low Energy connection act the same
// way that a ORS Serial connection does, so that the two can basically be used
// interchangeably.

import Foundation
import ORSSerial
import CoreBluetooth
import Combine


class BLEWrapper: NSObject {
    
    // To conserve bandwith, the BLE communication protocol uses a more rigid command
    // structure than the freeform ASCII commands of the Serial protocol.
    enum SliderCommand: UInt8 {
        case synchronize = 0x00
        case autohome = 0x01
        case stop = 0x02
        case go = 0x03
        case goto = 0x04
        case single = 0x05
        case ramp = 0x06
        case photo = 0x09
        case zero = 0x0A
        case release = 0x0B
        case position = 0x10
        case velocity = 0x11
        case status = 0x12
        case reset = 0xFF
    }
    
    var centralManager: CBCentralManager!
    var sliderBLEPeripheral: CBPeripheral!
    var sliderBLEPositionCharacteristic: CBCharacteristic!
    var sliderBLEVelocityCharacteristic: CBCharacteristic!
    var sliderBLEStateCharacteristic: CBCharacteristic!
    var sliderBLEInfoCharacteristic: CBCharacteristic!
    var sliderBLEStepperCharacteristic: CBCharacteristic!
    var sliderBLEResponseCharacteristic: CBCharacteristic!
    var sliderBLECommandCharacteristic: CBCharacteristic!
    let sliderInfoServiceCBUUID    = CBUUID(string: "b15d2c09-c973-44d3-b8a2-0b3839d5c6dd")
    let sliderCommandServiceCBUUID = CBUUID(string: "e5c9a2f3-3e2d-4e7c-b44e-8ba5c458969f")
    let stepperInfoServiceCBUUID = CBUUID(string: "06be228f-98a9-4783-ba74-ae71e3da7d63")
    
    let positionUUID = CBUUID(string: "a0fa9907-401d-407b-90f1-1eb6789a5ba2") // Notify-only, info service
    let velocityUUID = CBUUID(string: "fa4f6091-74ca-4fcb-ba32-7d3775399ba0") // Notify-only, info service
    let stateUUID    = CBUUID(string: "3df6decb-71a0-41fa-84b3-525da50306d6") // Notify-only, info service
    let infoUUID     = CBUUID(string: "f5785257-a390-4b32-b27d-0131a8c08574") // Notify-only, info service
    let stepperUUID     = CBUUID(string: "97eb9baf-2c9b-4778-b31d-8173e16a8639") // Notify-only, stepper service
    let responseUUID = CBUUID(string: "19d3ccbb-7884-47ab-808a-01fd776fefb3") // Notify-only, command service
    let commandUUID  = CBUUID(string: "ffe703e6-8747-418a-9f45-b8c4a4caaa7b") // Write no response, command service
    
    var position:[Int32] = [0,0,0,0]
    var positionPublisher:[ CurrentValueSubject<Int32, Never> ]
    
    var velocity:[Int32] = [0,0,0,0]
    var velocityPublisher:[ CurrentValueSubject<Int32, Never> ]
    
    var state:[UInt8] = [0,0,0,0]
    var statePublisher:[ CurrentValueSubject<UInt8, Never> ]
    
    @Published var info:String = ""
    @Published var error:String = ""
    
    @Published var systemStatus:SystemStatus = SystemStatus()
    
    @Published private(set) var connected = false
    private var readyForCommand = false
    private var lastCommand:SliderCommand?
    private var commandBuffer:[Data] = []
    
    private var communicationTimeout: Timer?
    
    override init() {
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
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // For BLE, all commands are sent blind: in general, no response is required. Sometimes the
    // slider will transmit some kind of response, and sometimes it will not. The obvious exception
    // is the position query commands, but from our perspective those are also blind, since they
    // simply trigger the slider to send an additional status update, of a sort we already have to
    // be handling in their un-requested form.
    func sendCommand (command:SliderCommand, motorCode:UInt8, parameters:[Int32]) {
        var commandData = Data()
        commandData.append(command.rawValue)
        commandData.append(motorCode)
        for parameter in parameters {
            var integerData = parameter
            commandData.append(withUnsafeBytes(of: &integerData,  { Data($0) }))
        }
        lastCommand = command
        sendCommand (data:commandData)
    }
    
    func sendCommand (command:SliderCommand, motorCode:UInt8, parameters:[UInt32]) {
        var commandData = Data()
        commandData.append(command.rawValue)
        commandData.append(motorCode)
        for parameter in parameters {
            var integerData = parameter
            commandData.append(withUnsafeBytes(of: &integerData,  { Data($0) }))
        }
        lastCommand = command
        sendCommand (data:commandData)
    }
    
    func sendCommand (command:SliderCommand, parameters:[Int32]) {
        if command == .go && lastCommand == .go && commandBuffer.count > 0 {
            // If the last command in the queue is a go, replace it with this go instead of appending:
            commandBuffer.removeLast()
        }
        lastCommand = command
        
        var commandData = Data()
        commandData.append(command.rawValue)
        for parameter in parameters {
            var integerData = parameter
            commandData.append(withUnsafeBytes(of: &integerData,  { Data($0) }))
        }
        sendCommand (data:commandData)
    }
    
    func sendCommand (command:SliderCommand) {
        lastCommand = command
        var commandData = Data()
        commandData.append(command.rawValue)
        sendCommand (data:commandData)
    }
    
    func sendCommand (data:Data) {
        commandBuffer.append(data)
        if readyForCommand {
            processCommandBuffer()
        }
    }
    
    func processCommandBuffer() {
        if !commandBuffer.isEmpty {
            readyForCommand = false
            let commandData = commandBuffer.removeFirst()
            sliderBLEPeripheral.writeValue(commandData, for: sliderBLECommandCharacteristic, type: .withoutResponse)
            communicationTimeout = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { timer in
                self.timeout();
            })
        }
    }
    
    func timeout () {
        print ("BLE Command timed out")
        error = "Command timed out."
        readyForCommand = true
    }
    
}

extension BLEWrapper: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            //print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: [sliderInfoServiceCBUUID,sliderCommandServiceCBUUID])
        @unknown default:
            print("central.state is in the unknown default state")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        sliderBLEPeripheral = peripheral
        peripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([sliderInfoServiceCBUUID,sliderCommandServiceCBUUID,stepperInfoServiceCBUUID])
    }
    
}

extension BLEWrapper: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print ("Failed to detect BLE services: \(error!.localizedDescription)")
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == sliderInfoServiceCBUUID {
                peripheral.discoverCharacteristics([positionUUID,velocityUUID,stateUUID,infoUUID], for: service)
            } else if service.uuid == stepperInfoServiceCBUUID {
                peripheral.discoverCharacteristics([stepperUUID], for: service)
            } else if service.uuid == sliderCommandServiceCBUUID {
                peripheral.discoverCharacteristics([responseUUID,commandUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print ("Error discovering descriptors for \(characteristic.uuid.uuidString)")
            return
        }
        
        for descriptor in characteristic.descriptors ?? [] {
            if descriptor.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString {
                peripheral.readValue(for: descriptor)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if descriptor.uuid.uuidString == CBUUIDCharacteristicUserDescriptionString {
            print ("Connected to data provider for \(descriptor.value as? NSString ?? "(No descriptor name)")")
        }
    }

    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            peripheral.discoverDescriptors(for: characteristic)
            if characteristic.uuid == positionUUID {
                sliderBLEPositionCharacteristic = characteristic
            } else if characteristic.uuid == velocityUUID {
                sliderBLEVelocityCharacteristic = characteristic
            } else if characteristic.uuid == stateUUID {
                sliderBLEStateCharacteristic = characteristic
            } else if characteristic.uuid == infoUUID {
                sliderBLEInfoCharacteristic = characteristic
            } else if characteristic.uuid == stepperUUID {
                sliderBLEStepperCharacteristic = characteristic
            } else if characteristic.uuid == responseUUID {
                sliderBLEResponseCharacteristic = characteristic
            } else if characteristic.uuid == commandUUID {
                sliderBLECommandCharacteristic = characteristic
                readyForCommand = true
            } else {
                print ("Unknown characteristic with UUID \(characteristic.uuid)")
            }
            
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
//        print ("------------------------------------------------------")
//        print ("Status: ")
//        print ("  sliderBLEPositionCharacteristic:\(sliderBLEPositionCharacteristic != nil)")
//        print ("  sliderBLEVelocityCharacteristic:\(sliderBLEVelocityCharacteristic != nil)")
//        print ("  sliderBLEStateCharacteristic:\(sliderBLEStateCharacteristic != nil)")
//        print ("  sliderBLEInfoCharacteristic:\(sliderBLEInfoCharacteristic != nil)")
//        print ("  sliderBLEResponseCharacteristic:\(sliderBLEResponseCharacteristic != nil)")
//        print ("  sliderBLECommandCharacteristic:\(sliderBLECommandCharacteristic != nil)")
//        print ("------------------------------------------------------")
        
         if sliderBLEPositionCharacteristic != nil &&
            sliderBLEVelocityCharacteristic != nil &&
            sliderBLEStateCharacteristic != nil &&
            sliderBLEInfoCharacteristic != nil &&
            sliderBLEStepperCharacteristic != nil &&
            sliderBLEResponseCharacteristic != nil &&
            sliderBLECommandCharacteristic != nil {
            print ("BLE setup complete. Ready to communicate.")
            connected = true
        } else {
            //print ("BLE setup not yet complete, not all characteristics are active yet.")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        //print ("Updated notification state for \(characteristic.uuid)")
        if let error = error {
            print ("BLE Notification setup error: \(error.localizedDescription)")
            if let bleErr = error as? CBError {
                print (String(format:"Error code: 0x%02X", bleErr.code.rawValue)) //E00002C2
                print(bleErr.errorUserInfo)
            }
            print ("Unable to get notifications from \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print ("BLE Notification Error: \(error.localizedDescription)")
            return
        }
        guard let value = characteristic.value else {
            return
        }
        switch characteristic.uuid {
        case positionUUID:
            self.position = value.withUnsafeBytes({ (data:UnsafeRawBufferPointer) in
                Array<Int32>(data.bindMemory(to: Int32.self))
            })
            for i in 0..<4 {
                self.positionPublisher[i].value = self.position[i]
            }
            //print ("BLE Position Update: \(self.position)")
        case velocityUUID:
            self.velocity = value.withUnsafeBytes({ (data:UnsafeRawBufferPointer) in
                Array<Int32>(data.bindMemory(to: Int32.self))
            })
            for i in 0..<4 {
                self.velocityPublisher[i].value = self.velocity[i]
            }
        case stateUUID:
            self.state = value.withUnsafeBytes({ (data:UnsafeRawBufferPointer) in
                Array<UInt8>(data.bindMemory(to: UInt8.self))
            })
            for i in 0..<4 {
                self.statePublisher[i].value = self.state[i]
            }
        case infoUUID:
            self.info = String(data: value, encoding: .ascii) ?? ""
            //print ("BLE Info: \(self.info)")
        case stepperUUID:
            systemStatus.parseBLEData(data: value)
        case responseUUID:
            if value.first != 0x01 {
                self.error = String(data: value.dropFirst() , encoding: .ascii) ?? ""
            } else {
                self.error = "None, BLE is OK"
            }
            readyForCommand = true
            if communicationTimeout?.isValid ?? false {
                communicationTimeout?.invalidate()
            } else {
                //print ("Response received when we were no longer awaiting one.")
            }
            processCommandBuffer()
        default:
            print("Unhandled characteristic UUID \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if let error = error {
            print ("Error writing BLE characteristic: \(error.localizedDescription)")
        } else {
            print ("Wrote BLE characteristics")
        }
    }
}
