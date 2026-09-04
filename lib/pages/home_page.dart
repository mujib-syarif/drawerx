import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const MethodChannel _channel = MethodChannel('drawerx/bubble');

  AssetEntity? latestScreenshot;

  Uint8List? thumbnail;
  Uint8List? fullImage;

  bool bubbleActive = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadData();
    checkBubbleStatus();
  }

  Future<void> checkBubbleStatus() async {
    try {
      final running = await _channel.invokeMethod<bool>('isBubbleRunning');

      if (!mounted) return;

      setState(() {
        bubbleActive = running == true;
      });
    } on PlatformException catch (e) {
      debugPrint('Bubble status error: ${e.message}');
    }
  }

  Future<void> loadData() async {
    try {
      final granted = await MediaService.requestPermission();

      if (!granted) {
        if (mounted) {
          setState(() {
            loading = false;
          });
        }
        return;
      }

      final screenshot = await MediaService.getLatestScreenshot();

      if (screenshot != null) {
        latestScreenshot = screenshot;

        thumbnail = await MediaService.getThumbnail(screenshot);

        fullImage = await screenshot.originBytes;
      }
    } catch (e) {
      debugPrint('Screenshot loading error: $e');
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> enableBubble() async {
    try {
      final permissionGranted = await _channel.invokeMethod<bool>(
        'requestOverlayPermission',
      );

      if (permissionGranted != true) {
        return;
      }

      await _channel.invokeMethod('startBubble');

      if (mounted) {
        setState(() {
          bubbleActive = true;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Bubble error: ${e.message}');
    }
  }

  Future<void> disableBubble() async {
    try {
      await _channel.invokeMethod('stopBubble');

      if (mounted) {
        setState(() {
          bubbleActive = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Bubble error: ${e.message}');
    }
  }

  void openEditor() {
    if (fullImage == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorPage(image: fullImage!)),
    );
  }

  TextStyle _font({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,

        titleSpacing: 16,

        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),

              child: Image.asset(
                'assets/images/drawerx_icon.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'DrawerX',
                  style: _font(
                    size: 19,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),

                Text(
                  'by @mujib_syarif',
                  style: _font(
                    size: 11,
                    weight: FontWeight.w500,
                    color: const Color(0xFFB9C0D4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: loadData,

        color: const Color(0xFF00D9FF),

        backgroundColor: const Color(0xFF151B2E),

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),

          children: [
            const SizedBox(height: 8),

            _buildWelcomeCard(),

            const SizedBox(height: 20),

            Text(
              'Screenshot Terbaru',
              style: _font(
                size: 20,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Screenshot terakhir yang tersimpan di perangkat',
              style: _font(
                size: 12,
                weight: FontWeight.w400,
                color: const Color(0xFFB0B7C9),
              ),
            ),

            const SizedBox(height: 12),

            _buildScreenshotCard(),

            const SizedBox(height: 20),

            _buildBubbleCard(),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.photo_library_rounded,
                    title: 'Galeri',
                    subtitle: 'Lihat screenshot',
                    onTap: () {},
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildMenuCard(
                    icon: Icons.settings_rounded,
                    title: 'Pengaturan',
                    subtitle: 'Atur DrawerX',
                    onTap: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Center(
              child: Text(
                'DrawerX by @mujib_syarif',
                style: _font(
                  size: 11,
                  weight: FontWeight.w500,
                  color: const Color(0xFF747D94),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [Color(0xFF151B38), Color(0xFF0D1024)],
        ),

        border: Border.all(color: Colors.white10),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: const BoxDecoration(
              shape: BoxShape.circle,

              gradient: LinearGradient(
                colors: [Color(0xFF00D9FF), Color(0xFF8B5CF6)],
              ),
            ),

            child: const Icon(
              Icons.edit_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Capture. Edit. Done.',
                  style: _font(
                    size: 17,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'Ambil screenshot, coret strategi, '
                  'dan langsung lanjut.',
                  style: _font(
                    size: 12,
                    weight: FontWeight.w400,
                    color: const Color(0xFFB5BCD0),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenshotCard() {
    if (loading) {
      return Container(
        height: 220,

        decoration: BoxDecoration(
          color: const Color(0xFF101528),
          borderRadius: BorderRadius.circular(22),
        ),

        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (thumbnail == null) {
      return Container(
        height: 220,

        decoration: BoxDecoration(
          color: const Color(0xFF101528),

          borderRadius: BorderRadius.circular(22),

          border: Border.all(color: Colors.white10),
        ),

        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              const Icon(
                Icons.image_not_supported_outlined,
                size: 42,
                color: Color(0xFF7E879D),
              ),

              const SizedBox(height: 10),

              Text(
                'Belum ada screenshot',
                style: _font(
                  size: 13,
                  weight: FontWeight.w500,
                  color: const Color(0xFFB0B7C9),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),

        border: Border.all(color: Colors.white10),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),

        child: Stack(
          children: [
            ScreenshotCard(thumbnail: thumbnail, onTap: openEditor),

            Positioned(
              top: 12,
              right: 12,

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: Colors.black54,

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: Colors.white,
                    ),

                    const SizedBox(width: 5),

                    Text(
                      'Edit',
                      style: _font(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101528),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white10),
      ),

      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

        secondary: Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            gradient: LinearGradient(
              colors: bubbleActive
                  ? const [Color(0xFF00D9FF), Color(0xFF8B5CF6)]
                  : const [Color(0xFF252A3D), Color(0xFF171A29)],
            ),
          ),

          child: Icon(
            Icons.bubble_chart_rounded,

            color: bubbleActive ? Colors.white : const Color(0xFF7E879D),
          ),
        ),

        title: Text(
          'DrawerX Bubble',
          style: _font(size: 14, weight: FontWeight.w700, color: Colors.white),
        ),

        subtitle: Text(
          bubbleActive
              ? 'Bubble aktif di atas aplikasi'
              : 'Aktifkan untuk akses cepat',

          style: _font(
            size: 11,
            weight: FontWeight.w400,
            color: const Color(0xFFB0B7C9),
          ),
        ),

        value: bubbleActive,

        onChanged: (value) {
          if (value) {
            enableBubble();
          } else {
            disableBubble();
          }
        },
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(20),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: const Color(0xFF101528),

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: Colors.white10),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),

                color: Colors.white.withValues(alpha: 0.06),
              ),

              child: Icon(icon, color: const Color(0xFFE1E5EF)),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              style: _font(
                size: 13,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              style: _font(
                size: 11,
                weight: FontWeight.w400,
                color: const Color(0xFF9DA6BA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
