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

  late final List<ServerSocket> _listenServers = [];

  bool _severStarted = false;
  bool? _useRemote = false;
  int _receiveBytes = 0;
  int _sendBytes = 0;
  List<String> ipList = [];

  TextEditingController? _listenIpController;
  TextEditingController? _fromPortController;
  TextEditingController? _toPortController;
  TextEditingController? _destIpController;
  ScrollController? _logScrollController;
  TextEditingController? _logController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _listenIpController = TextEditingController(text: '10.8.0.6');
    _fromPortController = TextEditingController(text: '10000');
    _destIpController = TextEditingController(text: '');
    _toPortController = TextEditingController(text: '65000');
    _logScrollController = ScrollController();
    _logController = TextEditingController();
  }

  Future<void> _getIp() async {
    ipList.clear();

    for (var interface in await NetworkInterface.list()) {
      for (var tAddr in interface.addresses) {
        setState(() {
          ipList.add(tAddr.address);
        });

        if (tAddr.address.startsWith('192')) {
          setState(() {
            _destIpController?.text = tAddr.address;
          });
        }
      }
    }
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

  Future<List<DropdownMenuItem<String>>> get ipItems async {
    List<DropdownMenuItem<String>> menuItems = [];

    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        menuItems.add(
            DropdownMenuItem(
                value: addr.address,
                child: Text(addr.address))
        );
      }
    }

    return menuItems;
  }

  // https://github.com/JulianAssmann/flutter_background/blob/master/example/lib/home_page.dart
  // https://gist.github.com/mgechev/5797992
  Widget _buildBody() {

    Future.delayed(Duration.zero, () async {
      await _getIp();
    });

    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Listen:',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _listenIpController,
                autovalidateMode: AutovalidateMode.always,
                validator: (str) => isValidHost(str) ? null : 'Invalid ip/hostname listen',
                decoration: const InputDecoration(
                  helperText: 'The IP address or hostname of the TCP listen',
                  hintText: 'Enter the address here, e.g. 10.0.2.2 for listen',
                )
              ),
              const SizedBox(height: 20),
              const Text('Port from/to:', style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              )),
              TextFormField(
                controller: _fromPortController,
                autovalidateMode: AutovalidateMode.always,
                validator: (str) => isValidPort(str) ? null : 'Invalid port from',
                decoration: const InputDecoration(
                  helperText: 'The port the TCP server is listening on',
                  hintText: 'Enter the port here, e. g. 10000 for from',
                ),
              ),
              TextFormField(
                controller: _toPortController,
                autovalidateMode: AutovalidateMode.always,
                validator: (str) => isValidPort(str) ? null : 'Invalid port to',
                decoration: const InputDecoration(
                  helperText: 'The port the TCP client is connect on',
                  hintText: 'Enter the port here, e. g. 80000 for to',
                ),
                enabled: _useRemote == false,
              ),
              CheckboxListTile(
                value: _useRemote,
                onChanged: (bool? value) {
                  setState(() {
                    _useRemote = value;
                  });
                },
                title: const Text('Enable remote listen start for port forwarding'),
                ),
              const SizedBox(height: 20),
              const Text('Destination:', style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 20),
              /*TextFormField(
                  controller: _destIpController,
                  autovalidateMode: AutovalidateMode.always,
                  validator: (str) => isValidHost(str) ? null : 'Invalid ip/hostname destination',
                  decoration: const InputDecoration(
                    helperText: 'The IP address or hostname of the TCP destination',
                    hintText: 'Enter the address here, e.g. 10.0.2.2 for destination',
                  )
              ),*/
              DropdownButton(
                value: _destIpController?.text,
                items: ipList.map((ip){
                  return DropdownMenuItem(
                      value: ip,
                      child: Text(ip)
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && (value is String)) {
                    setState(() {
                      _destIpController?.text = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  child: _severStarted ? const Text('Stop') : const Text('Start'),
                  onPressed: () {
                    if (_severStarted) {
                      _addLog("Stop listen ...");
                      _stopForwarding();

                      if (kDebugMode) {
                        print('Stop ...');
                      }
                      return;
                    }

                    if (kDebugMode) {
                      print('Start ...');
                    }

                    if (_formKey.currentState!.validate()) {
                      if (!_severStarted) {
                        _startForwarding(
                          _listenIpController!.text,
                          _destIpController!.text,
                          int.parse(_fromPortController!.text),
                          int.parse(_toPortController!.text),
                        );
                      }
                    } else {
                      _addLog("Invalidate, please check your settings!");
                    }
                  }
                ),

              const SizedBox(height: 20),
              Text('Receive-bytes: $_receiveBytes'),
              const SizedBox(height: 2),
              Text('Send-bytes: $_sendBytes'),
              const SizedBox(height: 20),
              TextField(
                scrollController: _logScrollController,
                controller: _logController,
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: "Logs ...",
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(width: 1, color: Colors.redAccent)
                    )
                ),

              )
            ]
          )
        )
    );
  }

  void _addLog(String log) {
    setState(() {
      _logController?.text = "${_logController?.text}\r\n$log";

      final logScrollController = _logScrollController;

      if (logScrollController != null) {
        logScrollController.jumpTo(logScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _openForwardingServer(String listenHost, int listPort, String destHost) async {
    try {
      _addLog("Bind listen: $listenHost:$listPort");

      ServerSocket server = await ServerSocket.bind(listenHost, listPort);
      server.listen((Socket serverSocket) async {
        Socket clientSocket = await Socket.connect(destHost, server.port);
        clientSocket.listen(
                (data) {
              setState(() {
                _receiveBytes += data.length;
              });

              try {
                serverSocket.add(data);
              } catch (ex) {
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
            onError: (error, StackTrace trace) async =>
            {
            },
            cancelOnError: true
        );

        serverSocket.listen((List<int> data) {
          setState(() {
            _sendBytes += data.length;
          });

          try {
            clientSocket.add(data);
          } catch (ex) {
            if (kDebugMode) {
              print(
                  '_startForwarding::serverSocket.listen: Exception write');
              print(ex);
            }
          }

          if (kDebugMode) {
            print('_startForwarding::serverSocket.listen:');
            print(data);
          }
        });
      });

      _listenServers.add(server);
    } catch (e) {
      _addLog('Can not bind the listen to: $listenHost:$listPort');
    }
  }

  /// _startForwarding
  Future<void> _startForwarding(String listenHost, String destHost, int fromPort, int toPort) async {
    _receiveBytes = 0;
    _sendBytes = 0;

    _addLog("Start listen ...");

    setState(() {
      _severStarted = true;
    });

    if (_useRemote == true) {
      _addLog("Start remote port forwarding listen on: $listenHost:$fromPort");

      final server = await HttpServer.bind(listenHost, fromPort);
      server.listen((request) async {
        _addLog('Request from: ${request.connectionInfo?.remoteAddress}');

        if (request.method == 'GET') {
          var pUri = Uri.parse(request.uri.toString());

          if (pUri.queryParameters.containsKey('action')) {
            var action = pUri.queryParameters['action'];

            switch (action) {
              case 'open_port':
                if (pUri.queryParameters.containsKey('port')) {
                  var portNum = int.parse(pUri.queryParameters['port']!);

                  _openForwardingServer(listenHost, portNum, destHost);

                  request.response.write('Port is open!');
                  request.response.close();
                  return;
                }
                break;

              case 'close_port':
                if (pUri.queryParameters.containsKey('port')) {
                  var portNum = int.parse(pUri.queryParameters['port']!);

                  for (var i = 0; i < _listenServers.length; i++) {
                    var isClose = false;

                    var server = _listenServers[i];

                    if (server.port == portNum) {
                      server.close();
                      isClose = true;
                    }

                    if (isClose) {
                      _listenServers.removeAt(i);
                      request.response.write('Port is close!');
                      request.response.close();
                      return;
                    }
                  }
                }
                break;

              case 'info':

                request.response.write('Listen-IP: $listenHost \r\n');
                request.response.write('Destination-IP: $destHost \r\n');
                request.response.write('Receive-bytes: $_receiveBytes \r\n');
                request.response.write('Send-bytes: $_sendBytes \r\n');
                request.response.write('\r\n');
                request.response.write('Open-Ports:\r\n');

                var ports = "";

                for (var i = 0; i < _listenServers.length; i++) {
                  ports += '${_listenServers[i].port}\r\n';
                }

                request.response.write('$ports\r\n');

                request.response.close();
                return;
            }
          }
        }

        request.response.statusCode = 404;
        request.response.close();
        return;
      });
    } else {
      for (int i = fromPort; i <= toPort; i++) {
        _openForwardingServer(listenHost, i, destHost);
      }
    }
  }

  /// _stopForwarding
  Future<void> _stopForwarding() async {
    _listenServers.map((server) {
      server.close();
    });

    _listenServers.clear();

    setState(() {
      _severStarted = false;
    });
  }
}