import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LegalContentSheet extends StatelessWidget {
  final String titleKey;
  final String contentKey; // Değişen parametre: Artık base path değil, direkt metnin key'i

  const LegalContentSheet({
    super.key,
    required this.titleKey,
    required this.contentKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Tutamaç (Handle Bar)
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded( // Uzun başlıklar için eklendi
                child: Text(
                  titleKey.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tüm metni tek bir Text widget'ı içinde basıyoruz
                    // JSON içindeki \n karakterleri burada otomatik olarak alt satıra geçecek
                    Text(
                      contentKey.tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4B5563),
                        height: 1.6, // Satır arası boşluk okunurluğu artırır
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}