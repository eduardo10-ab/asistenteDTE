import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models.dart';

class HomeScreen extends StatefulWidget {
  final ActivationStatus initialStatus;
  final Function(WebViewController) onWebViewRequested;
  final VoidCallback onStatusChangeNeeded;

  const HomeScreen({
    super.key,
    required this.initialStatus,
    required this.onWebViewRequested,
    required this.onStatusChangeNeeded,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

// Hacemos la clase pública para que pueda ser usada por GlobalKey
class HomeScreenState extends State<HomeScreen> {
  WebViewController? _webViewController;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            // Manejar inicio de carga
          },
          onPageFinished: (String url) {
            _updateCanGoBack();
          },
          onNavigationRequest: (NavigationRequest request) {
            // Aquí puedes manejar la navegación si es necesario
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://tusitio.com'),
      ); // Cambia esta URL por la que necesites

    setState(() {
      _webViewController = controller;
    });
    widget.onWebViewRequested(controller);
  }

  Future<void> _updateCanGoBack() async {
    if (_webViewController == null) return;

    final canGoBack = await _webViewController!.canGoBack();
    if (mounted && canGoBack != _canGoBack) {
      setState(() {
        _canGoBack = canGoBack;
      });
    }
  }

  Future<bool> handlePop() async {
    if (_webViewController == null) return true;

    if (await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_webViewController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WillPopScope(
      onWillPop: handlePop,
      child: Scaffold(body: WebViewWidget(controller: _webViewController!)),
    );
  }
}
