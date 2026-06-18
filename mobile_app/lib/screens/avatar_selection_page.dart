import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AvatarSelectionPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const AvatarSelectionPage({super.key, required this.student});

  @override
  State<AvatarSelectionPage> createState() => _AvatarSelectionPageState();
}

class _AvatarSelectionPageState extends State<AvatarSelectionPage> {
  static const Color primaryColor = Color(0xFF6C63FF);
  static final List<String> avatarAssets = List.generate(
    16,
    (index) => "assets/images/avatars/avatar_${index + 1}.png",
  );

  late String selectedAvatar;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedAvatar = (widget.student["avatar_asset"] ?? avatarAssets.first)
        .toString();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> saveAvatar(String avatarAsset) async {
    setState(() {
      selectedAvatar = avatarAsset;
      isSaving = true;
    });

    try {
      final updatedStudent = await ApiService.updateStudentAvatar(
        studentId: widget.student["id"] ?? 1,
        avatarAsset: avatarAsset,
      );

      if (!mounted) return;
      Navigator.pop(context, updatedStudent);
    } catch (e) {
      showMessage(e.toString().replaceFirst("Exception: ", ""));
    }

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget avatarOption(String avatarAsset) {
    final selected = selectedAvatar == avatarAsset;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: isSaving ? null : () => saveAvatar(avatarAsset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1EFFF) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? primaryColor : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: ClipOval(
                child: Image.asset(
                  avatarAsset,
                  width: 86,
                  height: 86,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (selected)
              const Positioned(
                right: 2,
                top: 2,
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: primaryColor,
                  child: Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7FF),
      appBar: AppBar(
        title: const Text("Avatar Seç"),
        centerTitle: true,
        backgroundColor: const Color(0xFFFCF7FF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Kullanmak istediğin avatarı seç.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: avatarAssets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                return avatarOption(avatarAssets[index]);
              },
            ),
            const SizedBox(height: 18),
            const Text(
              "Kendi görsellerini eklemek için dosyaları assets/images/avatars klasöründeki avatar_1.png - avatar_16.png dosyalarıyla değiştirebilirsin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
