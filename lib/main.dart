import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const EggPamApp());
}

class EggPamApp extends StatelessWidget {
  const EggPamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'เครื่องเก็บไข่ผำ',
      theme: ThemeData(
        primaryColor: const Color(0xFF007A33), // สีเขียวสถาบัน มรพส.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007A33),
          secondary: const Color(0xFFEAAA00), // สีทองสถาบัน มรพส.
        ),
        useMaterial3: true,
      ),
      home: const ControllerPage(),
    );
  }
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  String currentStatus = "เปิดบลูทูธบนมือถือเพื่อเตรียมเชื่อมต่อ";
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? writeCharacteristic;
  bool isConnecting = false;

  // UUID สำหรับใช้จับคู่สัญญาณบลูทูธกับบอร์ด ESP32
  final String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  final String characteristicUuidRx = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";

  @override
  void initState() {
    super.initState();
    // ระบบตรวจเช็กสถานะเพื่อบังคับเปิดบลูทูธบนมือถือเวลาจะเชื่อมต่อเครื่องจริง
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on) {
        setState(() { currentStatus = "บลูทูธพร้อมทำงาน กดค้นหาเครื่องได้เลย"; });
      } else {
        setState(() { currentStatus = "⚠️ กรุณาเปิดระบบบลูทูธบนโทรศัพท์มือถือ"; });
      }
    });
  }

  // ฟังก์ชันเริ่มสแกนค้นหาสัญญาณจากบอร์ด ESP32 ของจริง
  void startScanAndConnect() async {
    if (await FlutterBluePlus.isSupported == false) return;
    
    setState(() {
      isConnecting = true;
      currentStatus = "กำลังค้นหาเครื่องเก็บไข่ผำ (ESP32)...";
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == "ESP32" || r.device.advName == "ESP32") {
          await FlutterBluePlus.stopScan();
          connectToDevice(r.device);
          break;
        }
      }
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() { currentStatus = "เจออุปกรณ์แล้ว กำลังเชื่อมต่อระบบ..."; });
    try {
      await device.connect();
      targetDevice = device;

      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == characteristicUuidRx) {
              writeCharacteristic = characteristic;
              break;
            }
          }
        }
      }

      setState(() {
        isConnecting = false;
        currentStatus = "เชื่อมต่อระบบสำเร็จเรียบร้อย!";
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
        currentStatus = "เชื่อมต่อล้มเหลว กรุณาลองใหม่อีกครั้ง";
      });
    }
  }

  // ฟังก์ชันยิงคำสั่งสัญญาณบลูทูธออกไปหาบอร์ดจริงเพื่อคุมมอเตอร์
  void sendCommand(String command, String actionName) async {
    if (writeCharacteristic != null) {
      await writeCharacteristic!.write(command.codeUnits, withoutResponse: true);
      setState(() {
        currentStatus = "กำลังควบคุม: $actionName ($command)";
      });
    } else {
      setState(() {
        currentStatus = "⚠️ กรุณาเชื่อมต่อบลูทูธก่อนสั่งงาน";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = targetDevice != null && writeCharacteristic != null;

    return Scaffold(
      // แถบหัวข้อด้านบนสุด ปรับแก้ไขข้อความสั้นกระชับพร้อมชื่อสถาบันตามสั่งเป๊ะ
      appBar: AppBar(
        title: const Column(
          children: [
            Text('เครื่องเก็บไข่ผำ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('มหาวิทยาลัยราชภัฏพิบูลสงคราม พิษณุโลก', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF007A33),
        elevation: 4,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // แถบเส้นสีวิ่งเอฟเฟกต์ RGB เรืองแสงสวยงามตกแต่งหน้าจอแอปพลิเคชัน
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // หน้าปัดรายงานผลการเชื่อมต่อบลูทูธ
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text("เครื่องเก็บไข่ผำ", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF007A33))),
                        const Text("มหาวิทยาลัยราชภัฏพิบูลสงคราม พิษณุโลก", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                        const Divider(height: 25),
                        ElevatedButton.icon(
                          onPressed: (isConnecting || isConnected) ? null : startScanAndConnect,
                          icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching),
                          label: Text(isConnected ? 'เชื่อมต่อสำเร็จแล้ว' : isConnecting ? 'กำลังสแกนหา...' : 'กดเพื่อเชื่อมต่อบลูทูธ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected ? Colors.blue.shade600 : const Color(0xFF333333),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(currentStatus, style: TextStyle(color: isConnected ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // แผงจอยสติ๊กปุ่มกดสั่งงานมอเตอร์ใบพัดคู่ขับเคลื่อน
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: Colors.cyan.withOpacity(0.12), blurRadius: 10, spreadRadius: 2),
                        BoxShadow(color: Colors.purple.withOpacity(0.12), blurRadius: 10, spreadRadius: 2),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Column(
                        children: [
                          const Text('แผงควบคุมการขับเคลื่อนมอเตอร์', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 25),
                          // เดินหน้า (F)
                          InkWell(
                            onTap: () => sendCommand("F", "เดินหน้า"),
                            child: Icon(Icons.arrow_circle_up_rounded, size: 85, color: const Color(0xFF007A33).withOpacity(0.9)),
                          ),
                          // ซ้าย (L) และ ขวา (R)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => sendCommand("L", "เลี้ยวซ้าย"),
                                child: const Icon(Icons.arrow_circle_left_rounded, size: 85, color: Color(0xFF007A33)),
                              ),
                              const SizedBox(width: 45),
                              InkWell(
                                onTap: () => sendCommand("R", "เลี้ยวขวา"),
                                child: const Icon(Icons.arrow_circle_right_rounded, size: 85, color: Color(0xFF007A33)),
                              ),
                            ],
                          ),
                          // ถอยหลัง (B)
                          InkWell(
                            onTap: () => sendCommand("B", "ถอยหลัง"),
                            child: Icon(Icons.arrow_circle_down_rounded, size: 85, color: const Color(0xFF007A33).withOpacity(0.9)),
                          ),
                          const SizedBox(height: 25),
                          // ปุ่มหยุดเครื่องฉุกเฉิน (S)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 35.0),
                            child: ElevatedButton.icon(
