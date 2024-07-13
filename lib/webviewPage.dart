import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebView(
          initialUrl: "https://poloceleste.netlify.app",
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onPageFinished: (url) {
            String message = "FLUTTER MESSAGE";
            _controller.runJavascript('fromAppToWeb("$message")');
            print("플러터앱에서 웹으로 메시지 전송: $message");
          },
          javascriptMode: JavascriptMode.unrestricted,
          javascriptChannels: <JavascriptChannel>{
            JavascriptChannel(
                name: 'toApp',
                onMessageReceived: (JavascriptMessage message) {
                  print("웹에서 플러터앱으로 메시지 전송: ${message.message}");
                  Navigator.of(context).pop();
                }),
          },
        ),
      ),
    );
  }
}
