import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothService {

  FlutterBluetoothSerial _bluetoothSerial = FlutterBluetoothSerial.instance;

  //BluetoothDevice device;
  String nameOfDevice;
  String macOfDevice;
  bool streamActive = false;
  bool isConnected = false;
  BluetoothConnection connection;
  Future<bool> get isBluetoothEnabled async => await _bluetoothSerial.isEnabled;
  Future<bool> get isBluetoothExists async => await _bluetoothSerial.isAvailable;
  //Future<bool> get isBluetoothConnected async => device.isConnected;
  
  //Stream<BluetoothDiscoveryResult> discoveryStream => _bluetoothSerial.startDiscovery();
  ///StreamSubscription used to discover BluetoothDiscoveryResults
  ///
  ///Make sure you first call the function startListeningForBluetoothDiscoveryResult(). Otherwise this will be null
  StreamSubscription<BluetoothDiscoveryResult> _discoveryStreamSubscription;

  ///StreamSubscription used to listen to incoming data from the Bluetooth Module
  ///
  ///Make sure you first call the function listenToDevice(). Otherwise this will be null
  StreamSubscription<Uint8List> _connectionStreamSubscription;

  Stream<Uint8List> _connectionStream;

  Future<void> saveDevice(BluetoothDevice device) async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('macOfDevice', device.address);  
    await prefs.setString('nameOfDevice', device.name);
    print(prefs.getString("MAC_Bluetooth"));
  }

  Future<String> getSavedDeviceMAC() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("macOfDevice");
  }

  Future<String> getSavedDeviceName() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("nameOfDevice");
  }

  
  Stream<BluetoothDiscoveryResult> _discoveryStream;  

  ///Initialize discoveryStream that listens to bluetooth discovery result.
  ///Use dicoveryStream.listen((BluetoothDiscoveryResult){ do something with BluetoothDiscoveryResult});
  ///Check if there is an existing Bluetoothadapter first and if it is enabled
  void startDiscovering(Function onResult(BluetoothDiscoveryResult r)){
 
    setupDiscoveryStream();
    _discoveryStreamSubscription = _discoveryStream.listen((result) {onResult(result);});
  
  }

  ///Excecutes the given function when the discovery is done
  void onDiscoveryDone(Function onDone){
    _discoveryStreamSubscription.onDone(onDone);
  }

  ///Executes the given function when there is an error while discovering
  void onDiscoveryError(Function onError){
    _discoveryStreamSubscription.onError(onError);
  }

  ///Sets up a discovery stream.
  void setupDiscoveryStream(){
    _discoveryStream = _bluetoothSerial.startDiscovery();

  }

  ///Cancel the current discoveryStreamSubsciption.
  void cancelDiscoveryStreamSubscription(){
    _discoveryStreamSubscription.cancel();
  }

  ///asks for activating Bluetooth.
  ///Wil call given function when bluetooth is enabled
  Future<void> enableBluetooth(Function ifBluetoothIsTurnedOn, Function ifBluetoothIsNotTurnedOn) async{
    await FlutterBluetoothSerial.instance.requestEnable();
    if(await FlutterBluetoothSerial.instance.isEnabled){
      ifBluetoothIsTurnedOn();
      toast("Bluetooth succesfully turned on");
    }
    else{
      ifBluetoothIsNotTurnedOn();
      toast("Bluetooth not turned on");
    }
  }

  ///Sets up a connection stream.
  Future<void> setupConnectionStream() async{
    _connectionStream = connection.input.asBroadcastStream();
  }

  ///Creates a StreamSubsription that will call the given function when data is recieved.
  void startListening(Function onRecievingData){
    _connectionStreamSubscription = _connectionStream.listen(onRecievingData);    
  }

  ///Executes the given function when listening is done.
  void onListeningDone(Function onDone){
    _connectionStreamSubscription.onDone(onDone);
  }

  ///Executes the given function when there is an error while listening.
  void onListeningError(Function onError){
    _connectionStreamSubscription.onError(onError);
  }

  ///closes the current connectionStreamSubscription that listens to the bluetooth module.
  void cancelConnectionStreamSubsciption(){
    _connectionStreamSubscription.cancel();
  }

  ///sendMessage to the current connection.
  ///This will only send data if a connection is available
  Future<void> sendMessage(String message) async {
    if(connection.isConnected){
      connection.output.add(utf8.encode(message));
      connection.output.allSent;
      print("sended");
    }    
  }


  ///The app will pair and connect to the device given as a BluetoothDiscoveryResult.
  ///onAlreadyBonded will be called when the device is already paired with the device
  ///onNotBonded will be called when the device is not already bonden. The function wil pair with the device before calling this function
  ///onError will be called if there where any errors
  ///
  ///This function will also automatically connect with the given device!
  Future<void> pairWithDevice(BluetoothDiscoveryResult result,Function onBonded,Function onError(String ex)) async{
    try{
      bool bonded;
      if(result.device.isBonded){
        connect(result.device,onBonded());
        
       
        saveDevice(result.device);
        
      }
      else{
        print('Bonding with ${result.device.address}...');
        bonded = await FlutterBluetoothSerial.instance.bondDeviceAtAddress(result.device.address);
        print('Bonding with ${result.device.address} has ${bonded ? 'succed' : 'failed'}.');
        //toastOnSucces();
         
        if(bonded){
          connect(result.device,onBonded());
          
        }
        else{
          onError("Unknown error. Make sure you entered the correct PIN.");
        }                             
      }      
    }
    catch(ex){
      toast("Error while pairing");
      onError(ex.toString());
    }
  } 

  

  void toastOnSucces(){
    Fluttertoast.showToast(
              msg: "Succesfully connected",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              fontSize: 16.0
          );
  }

  void toast(String message){
    Fluttertoast.showToast(
              msg: message,
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              fontSize: 16.0
          );
  }

  //Here the _connectionStream is set without using the function setupConnectionStream because that gave error. 
  ///Connects with a given Bluetooth device and set up a connection stream.
   /*connect(BluetoothDevice _device) => {
     
    BluetoothConnection.toAddress(_device.address).then((_connection) {
          print('Connected to the device');
          connection = _connection;
          //device = _device;
          isConnected = true;
          setupConnectionStream();
          return true;
        }).catchError((error) {
          print('Cannot connect, exception occured');
          print(error);
          return false;
        }).then((value) => (){
          if(isConnected == true){
            //nameOfDevice = _device.name;
            //macOfDevice = _device.address;
            
            toast("Succes");
          }
        })
  

  };*/

  Future<void> connect(BluetoothDevice _device, Function f) async{
     BluetoothConnection.toAddress(_device.address).then((_connection) {
          print('Connected to the device');
          connection = _connection;
          //device = _device;
          isConnected = true;
          setupConnectionStream();
          return true;
        }).catchError((error) {
          print('Cannot connect, exception occured');
          print(error);
          return false;
        }).whenComplete(() => onConnected(f));
  }

  void onConnected(Function f){
    if(isConnected == true)    
    toast("Succesfully connected!");
    f();
  }

  
  Future<void> connectWithSavedDevice() async{
    String mac = await getSavedDeviceMAC(); 
    print(mac);
    print("isConnected" + isConnected.toString());
    if(mac != null && isConnected == false){
     
        BluetoothConnection.toAddress(mac).then((_connection) {
              //print('Connected to the device');
              connection = _connection;
              isConnected = true;   
              //createBluetoothDevice(mac);    
              //setupConnectionStream();
              return true;
            }).catchError((error) {
              print('Cannot connect, exception occured');
              print(error);
              AlertDialog(
                title:Text("Error"),
                content: error,
                );
              //toast(error);
              return false;
            }).whenComplete(() => createBluetoothDevice(mac));
      
    }
  }

  void createBluetoothDevice(String mac)async{
    if(isConnected == true){
      //setupConnectionStream();
      //print("CREATE BLUETOOTH DEVICE");
      nameOfDevice = await getSavedDeviceName();
      macOfDevice = await getSavedDeviceMAC();
      toast("Succesfully conected with " +nameOfDevice+".");
      
    }
  }
  
}

