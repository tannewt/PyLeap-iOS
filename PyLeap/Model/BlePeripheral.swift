//
//  BlePeripheral.swift
//  PyLeap
//
//  Created by Trevor Beaton For Adafruit Industries on 3/9/21.
//

import Foundation
import CoreBluetooth

protocol BluefruitDelegate {
    func bluefruitDidConnect(supported: Bool, buttonSupported: Bool)
    func bluefruitDidDisconnect()
    func buttonStateChanged(isPressed: Bool)
    func stateChanged(isOn: Bool)
}

class BlePeripheral: NSObject {
 static var connectedPeripheral: CBPeripheral?
 static var connectedService: CBService?
 static var connectedTXChar: CBCharacteristic?
 static var connectedRXChar: CBCharacteristic?

    private let centralManager: CBCentralManager
    private let basePeripheral: CBPeripheral
    public  var localName: String?
    public  var advertData: [String : Any]?
    public  var advertisement: Advertisement

    public var isConnected: Bool {
        return basePeripheral.state == .connected
    }
    
    // MARK: - Characteristic properties
    
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    
    
    var identifier: UUID {
        return basePeripheral.identifier
    }

    var name: String? {
        return basePeripheral.name
    }

    var state: CBPeripheralState {
        return basePeripheral.state
    }
    
    

    
    
    //MARK:- Advertisment
    
    struct Advertisement {
       
        var advertisementData: [String: Any]

        init(advertisementData: [String: Any]?) {
            self.advertisementData = advertisementData ?? [String: Any]()
        }

        // Advertisement data formatted
        var localName: String? {
            return advertisementData[CBAdvertisementDataLocalNameKey] as? String
        }
        
        var manufacturerData: Data? {
            return advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        }
        
        var manufacturerHexDescription: String? {
            guard let manufacturerData = manufacturerData else { return nil }
            return HexUtil.hexDescription(data: manufacturerData)
//            return String(data: manufacturerData, encoding: .utf8)
        }
        
        var manufacturerIdentifier: Data? {
            guard let manufacturerData = manufacturerData, manufacturerData.count >= 2 else { return nil }
            let manufacturerIdentifierData = manufacturerData[0..<2]
            return manufacturerIdentifierData
        }

        var services: [CBUUID]? {
            return advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        }

        var servicesOverflow: [CBUUID]? {
            return advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
        }

        var servicesSolicited: [CBUUID]? {
            return advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
        }
        
        var serviceData: [CBUUID: Data]? {
            return advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data]
        }

        var txPower: Int? {
            let number = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
            return number?.intValue
        }

        var isConnectable: Bool? {
            let connectableNumber = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
            return connectableNumber?.boolValue
        }
    }
    
    
    init(withPeripheral peripheral: CBPeripheral,
         advertisementData advertisementDictionary: [String : Any],
         with manager: CBCentralManager) {
    
    centralManager = manager
    basePeripheral = peripheral
    advertisement = Advertisement(advertisementData: advertisementDictionary)
        
    super.init()
    localName = parseAdvertisementData(advertisementDictionary)
    advertData = advertisementDictionary
    basePeripheral.delegate = self
    
    }
    
    /// Connects to the device.
    public func connect() {
        centralManager.delegate = self
        print("Connecting to Adafruit device...")
        centralManager.connect(basePeripheral, options: nil)
    }
    
    /// Cancels existing or pending connection.
    public func disconnect() {
        print("Cancel connection...")
        centralManager.cancelPeripheralConnection(basePeripheral)
    }
    
    private func parseAdvertisementData(_ advertisementDictionary: [String : Any]) -> String? {
        var localName: String

        if let name = advertisementDictionary[CBAdvertisementDataLocalNameKey] as? String{
            localName = name
        } else {
            localName = "\(name ?? "Unknown Device")"
        }
        
        return localName
    }
    
    public func writeOutgoingValue(data: String){

        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)

        basePeripheral.writeValue(valueString!, for: txCharacteristic!, type: CBCharacteristicWriteType.withResponse)

          }
      
    private func writeTxCharcateristic(withValue value: Data) {
        if let txCharacteristic = txCharacteristic {
            if txCharacteristic.properties.contains(.write) {
                print("Writing value (with response)...")
                basePeripheral.writeValue(value, for: txCharacteristic, type: .withResponse)
           
            } else if txCharacteristic.properties.contains(.writeWithoutResponse) {
                print("Writing value... (without response)")
                basePeripheral.writeValue(value, for: txCharacteristic, type: .withoutResponse)
                // peripheral(_:didWriteValueFor,error) will not be called after write without response
                // we are caling the delegate here
                
            } else {
                print("Characteristic is not writable")
            }
        }
    }
    
    // MARK: - Implementation
    
    
    private func discoverServices() {
        print("Discovering LED Button service...")
        basePeripheral.delegate = self
        basePeripheral.discoverServices([])
    }
    
    /// A callback called when the Bluetooth characteristic value has changed.
    private func didReceiveButtonNotification(withValue value: Data) {
        print("Value changed: \(value[0])")
       // delegate?.buttonStateChanged(isPressed: value[0] == 0x1)
    }

}

extension BlePeripheral: CBCentralManagerDelegate {
    // MARK: - Check
    func centralManagerDidUpdateState(_ central: CBCentralManager) {

      switch central.state {
        case .poweredOff:
            print("Is Powered Off.")
        case .poweredOn:
            print("Is Powered On.")
            
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
        print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
          print("Error")
        }
    }

    // MARK: - Discover
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
   
    }

    // MARK: - Connect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == basePeripheral {
            print("Connected to device")
            discoverServices()
        }
        
        //      print("PyLeap has connected to Peripheral: \(tempBluefruitPeripheral.name)")
//
//
//
//      tempBluefruitPeripheral.discoverServices([NUSCBUUID.BLEService_UUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        
    }
    
    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        
    }
    
}

extension BlePeripheral: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if characteristic == txCharacteristic {
            if let value = characteristic.value{
                print("Tx Update Value: \(value)")
           
            } else if characteristic == rxCharacteristic {
                if let value = characteristic.value {
                print("Rx Update Value: \(value)")
                }
            }
            
        }
        
    
        
//      var characteristicASCIIValue = NSString()
//
//      guard characteristic == tempRxCharacteristic,
//
//            let characteristicValue = characteristic.value,
//            let ASCIIstring = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) else { return }
//
//        characteristicASCIIValue = ASCIIstring
//
//      print("Value Recieved: \((characteristicASCIIValue as String))")
//
//      NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: "\((characteristicASCIIValue as String))")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        print("*******************************************************")

        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard let services = peripheral.services else {
            return
        }
        
        //We need to discover the all characteristic
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services.count)")
        
        //        if let services = peripheral.services {
//            for service in services {
//                if service.uuid == BlinkyPeripheral.nordicBlinkyServiceUUID {
//                    print("LED Button service found")
//                    //Capture and discover all characteristics for the blinky service
//                    discoverCharacteristicsForBlinkyService(service)
//                    return
//                }
//            }
//        }
//        // Blinky service has not been found
//        delegate?.blinkyDidConnect(ledSupported: false, buttonSupported: false)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

               guard let characteristics = service.characteristics else {
              return
          }

          print("Found \(characteristics.count) characteristics.")

          for characteristic in characteristics {

            if characteristic.uuid.isEqual(NUSCBUUID.BLE_Characteristic_uuid_Rx)  {

              rxCharacteristic = characteristic

              peripheral.setNotifyValue(true, for: rxCharacteristic!)
              peripheral.readValue(for: characteristic)

                print("RX Characteristic: \(rxCharacteristic?.uuid)")
            }

            if characteristic.uuid.isEqual(NUSCBUUID.BLE_Characteristic_uuid_Tx){

              txCharacteristic = characteristic
                
                print("TX Characteristic: \(txCharacteristic?.uuid)")


            }

          }
     // perform(#selector(delayedConnection), with: nil)
      //delayedConnection()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // LED value has been written, let's read it to confirm.
        readValue()
    }
    
    public func readValue() {
        if let txCharacteristic = txCharacteristic {
            if txCharacteristic.properties.contains(.read) {
                print("Reading characteristic...")
                basePeripheral.readValue(for: txCharacteristic)
            } else {
                print("Can't read state")
        
            }
        }
    }
    
    
}
