import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qiscus_chat_sdk/qiscus_chat_sdk.dart';
import 'package:flutter/widgets.dart';

import 'chat_room_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MyHomepage();
}

class MyHomepage extends StatefulWidget {
  @override
  _MyHomepageState createState() => _MyHomepageState();
}

class _MyHomepageState extends State<MyHomepage> {
  QiscusSDK _qiscusSDK;
  QChatRoom room;

  QiscusSDK get qiscus => _qiscusSDK;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _qiscusSDK = QiscusSDK.withAppId('sdksample', callback: (error) {
        if (error != null) {
          return print('Error happend while initializing qiscus sdk: $error');
        }
        print('Qiscus SDK Ready to use');
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _qiscusSDK?.clearUser(callback: (error) {
      // ignore error
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<QChatRoom>(
        future: Future.microtask(() async {
          await _init();
          await _login();
          var room = await _getRoom();
          return room;
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            var room = snapshot.data;
            return ChatRoomPage(
              qiscus: qiscus,
              room: room,
            );
          } else {
            return Container(
              child: Center(
                child: Text('Something bad happen, please check logs.'),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _init() async {
    var completer = Completer<void>();

    const appId = 'sdksample';
    qiscus.setup(appId, callback: (error) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete();
      }
    });

    return completer.future;
  }

  Future<QAccount> _login() async {
    var completer = Completer<QAccount>();

    const userId = 'guest-101';
    const userKey = 'passkey';

    qiscus.setUser(
      userId: userId,
      userKey: userKey,
      callback: (account, error) {
        if (error != null) {
          completer.completeError(error);
        } else {
          completer.complete(account);
        }
      },
    );

    return completer.future;
  }

  Future<QChatRoom> _getRoom() async {
    var completer = Completer<QChatRoom>();

    const targetUser = 'guest-102';
    qiscus.chatUser(
      userId: targetUser,
      callback: (room, error) {
        if (error != null) {
          completer.completeError(error);
        } else {
          setState(() {
            this.room = room;
          });
          completer.complete(room);
        }
      },
    );

    return completer.future;
  }
}
