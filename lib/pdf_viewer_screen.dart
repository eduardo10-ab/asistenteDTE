import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';

class PDFViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const PDFViewerScreen({
    Key? key,
    required this.filePath,
    this.title = 'Visor de PDF',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Share.shareXFiles([
                XFile(filePath),
              ], subject: 'Compartir PDF');
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Ya está guardado en filePath
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF guardado en: $filePath'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cargar el PDF: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
        onPageError: (page, error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en la página $page: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }
}
