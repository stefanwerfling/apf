import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ForwardingPage extends StatefulWidget {
  const ForwardingPage({Key? key}) : super(key: key);

  @override
  State<ForwardingPage> createState() => _ForwardingPage();
}

class _ForwardingPage extends State<ForwardingPage> {

  late Future<ServerSocket> _listenServer;
  bool _severStarted = false;
  int _receiveBytes = 0;
  int _sendeBytes = 0;
  TextEditingController? _ListenIpController;
  TextEditingController? _ListenPortController;
  TextEditingController? _DestIpController;
  TextEditingController? _DestPortController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _ListenIpController = TextEditingController(text: '10.8.0.6');
    _ListenPortController = TextEditingController(text: '6666');
    _DestIpController = TextEditingController(text: '');
    _DestPortController = TextEditingController(text: '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text('Android port forwarding')
        ),
        body: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBody()
              ]
          )
        )
    );
  }

  isValidHost(String? str) {
    if (str == null || str.isEmpty) return false;
    final ipAddressExp = RegExp(
        r'^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$');
    final hostnameExp = RegExp(
        r'^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$');
    return ipAddressExp.hasMatch(str) || hostnameExp.hasMatch(str);
  }

  /// Validates a TCP port
  bool isValidPort(String? str) {
    if (str == null || str.isEmpty) return false;
    final regex = RegExp(
        r'^([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$');
    return regex.hasMatch(str);
  }

  // https://github.com/JulianAssmann/flutter_background/blob/master/example/lib/home_page.dart
  // https://gist.github.com/mgechev/5797992
  Widget _buildBody() {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text('Listen:'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _ListenIpController,
                autovalidateMode: AutovalidateMode.always,
                validator: (str) => isValidHost(str) ? null : 'Invalid ip/hostname listen',
                decoration: const InputDecoration(
                  helperText: 'The IP address or hostname of the TCP listen',
                  hintText: 'Enter the address here, e.g. 10.0.2.2 for listen',
                )
              ),
              TextFormField(
                controller: _ListenPortController,
                autovalidateMode: AutovalidateMode.always,
                validator: (str) => isValidPort(str) ? null : 'Invalid port listen',
                decoration: const InputDecoration(
                  helperText: 'The port the TCP server is listening on',
                  hintText: 'Enter the port here, e. g. 6666 for listen',
                ),
              ),
              const SizedBox(height: 20),
              const Text('Destination:'),
              const SizedBox(height: 20),
              TextFormField(
                  controller: _DestIpController,
                  autovalidateMode: AutovalidateMode.always,
                  validator: (str) => isValidHost(str) ? null : 'Invalid ip/hostname destination',
                  decoration: const InputDecoration(
                    helperText: 'The IP address or hostname of the TCP destination',
                    hintText: 'Enter the address here, e.g. 10.0.2.2 for destination',
                  )
              ),
              TextFormField(
                controller: _DestPortController,
                autovalidateMode: AutovalidateMode.always,
                validator: (str) => isValidPort(str) ? null : 'Invalid port destination',
                decoration: const InputDecoration(
                  helperText: 'The port the TCP client is connect on',
                  hintText: 'Enter the port here, e. g. 6666 for destination',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  child: _severStarted ? const Text('Stop') : const Text('Start'),
                  onPressed: () {
                    if (_severStarted) {
                      if (kDebugMode) {
                        print('Stop ...');
                      }
                      return;
                    }

                    if (kDebugMode) {
                      print('Start ...');
                    }

                    if (_formKey.currentState!.validate()) {
                      _startForwarding(
                        _ListenIpController!.text,
                        int.parse(_ListenPortController!.text),
                        _DestIpController!.text,
                        int.parse(_DestPortController!.text),
                      );
                    }
                  }
                ),

              const SizedBox(height: 20),
              Text('Receive-bytes: $_receiveBytes'),
              const SizedBox(height: 2),
              Text('Send-bytes: $_sendeBytes'),
            ]
          )
        )
    );
  }

  Future<void> _startForwarding(String listenHost, int listenPort, String destHost, int destPort) async {
    _listenServer = ServerSocket.bind(listenHost, listenPort);
    _listenServer.then((ServerSocket server) {
      server.listen((Socket serverSocket) async {
        Socket clientSocket = await Socket.connect(destHost, destPort);
        clientSocket.listen(
            (data) {
              setState(() {
                _receiveBytes += data.length;
              });

              try {
                serverSocket.add(data);
              } catch(ex) {
                if (kDebugMode) {
                  print('clientSocket.listen: Exception write');
                  print(ex);
                }
              }

              if (kDebugMode) {
                print('clientSocket.listen:');
                print(data);
              }
            },
            onError: (error, StackTrace trace) async => {
            },
            cancelOnError: true
        );

        serverSocket.listen((List<int> data) {
          setState(() {
            _sendeBytes += data.length;
          });

          try {
            clientSocket.add(data);
          } catch(ex) {
            if (kDebugMode) {
              print('_startForwarding::serverSocket.listen: Exception write');
              print(ex);
            }
          }

          if (kDebugMode) {
            print('_startForwarding::serverSocket.listen:');
            print(data);
          }
        });
      });
    });

    setState(() {
      _severStarted = true;
    });
  }

}