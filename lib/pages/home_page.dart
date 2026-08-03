import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/media_service.dart';
import '../widgets/screenshot_card.dart';
import 'editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AssetEntity? latestScreenshot;

  Uint8List? thumbnail;

  Uint8List? fullImage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final granted = await MediaService.requestPermission();

    if (!granted) return;

    latestScreenshot = await MediaService.getLatestScreenshot();

    if (latestScreenshot != null) {
      thumbnail = await MediaService.getThumbnail(latestScreenshot!);

      fullImage = await latestScreenshot!.originBytes;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DrawerX"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Screenshot Terbaru",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          ScreenshotCard(
            thumbnail: thumbnail,
            onTap: () {
              if (fullImage == null) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditorPage(image: fullImage!),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          const ListTile(
            leading: Icon(Icons.photo_library),
            title: Text("Galeri"),
          ),

          const Divider(),

          const ListTile(
            leading: Icon(Icons.settings),
            title: Text("Pengaturan"),
          ),
        ],
      ),
    );
  }
}
