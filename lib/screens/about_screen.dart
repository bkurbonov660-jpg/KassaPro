import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<PhotoProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(translate(context, 'about_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate(context, 'why_permissions'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  _faqItem(context, '📷', translate(context, 'perm_camera'), translate(context, 'perm_camera_desc')),
                  _faqItem(context, '🖼️', translate(context, 'perm_gallery'), translate(context, 'perm_gallery_desc')),
                  _faqItem(context, '💾', translate(context, 'perm_storage'), translate(context, 'perm_storage_desc')),
                  _faqItem(context, '📤', translate(context, 'perm_share'), translate(context, 'perm_share_desc')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translate(context, 'faq'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  _faqItem(context, '❓', translate(context, 'faq_what_is'), translate(context, 'faq_what_is_ans')),
                  _faqItem(context, '🔒', translate(context, 'faq_data_safety'), translate(context, 'faq_data_safety_ans')),
                  _faqItem(context, '🔄', translate(context, 'faq_export'), translate(context, 'faq_export_ans')),
                  _faqItem(context, '🌐', translate(context, 'faq_language'), translate(context, 'faq_language_ans')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Sisms Photo v1.0\n© 2026',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faqItem(BuildContext context, String icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
                Text(desc, style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String translate(BuildContext context, String key) {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    final dict = {
      'ru': {
        'about_title': 'О приложении',
        'why_permissions': 'Зачем нужны разрешения?',
        'perm_camera': 'Камера',
        'perm_camera_desc': 'Чтобы делать фотографии прямо в приложении.',
        'perm_gallery': 'Галерея',
        'perm_gallery_desc': 'Чтобы выбирать уже существующие фото из вашей галереи.',
        'perm_storage': 'Хранилище',
        'perm_storage_desc': 'Чтобы сохранять фото в локальную базу приложения и экспортировать данные.',
        'perm_share': 'Поделиться',
        'perm_share_desc': 'Чтобы отправлять фото друзьям через другие приложения.',
        'faq': 'Часто задаваемые вопросы',
        'faq_what_is': 'Что это за приложение?',
        'faq_what_is_ans': 'Sisms Photo — это каталог ваших фотографий с возможностью добавлять названия и описания, искать, сортировать и обмениваться данными через QR-код.',
        'faq_data_safety': 'Безопасны ли мои данные?',
        'faq_data_safety_ans': 'Да, все ваши фото и данные хранятся только локально на вашем устройстве. Никакие данные не отправляются в интернет.',
        'faq_export': 'Как перенести данные на другой телефон?',
        'faq_export_ans': 'Используйте полный экспорт (создаёт папку с фото и метаданными) или QR-код для текстовой информации.',
        'faq_language': 'Можно ли сменить язык?',
        'faq_language_ans': 'Да, в настройках вы можете выбрать русский или таджикский язык.',
      },
      'tg': {
        'about_title': 'Дар бораи барнома',
        'why_permissions': 'Барои чӣ иҷозатҳо лозиманд?',
        'perm_camera': 'Камера',
        'perm_camera_desc': 'Барои акс гирифтан дар худи барнома.',
        'perm_gallery': 'Галерея',
        'perm_gallery_desc': 'Барои интихоби аксҳои мавҷуда аз галереяи шумо.',
        'perm_storage': 'Нигоҳдорӣ',
        'perm_storage_desc': 'Барои нигоҳ доштани аксҳо дар пойгоҳи маҳаллӣ ва экспорти маълумот.',
        'perm_share': 'Мубодила',
        'perm_share_desc': 'Барои фиристодани акс ба дӯстон тавассути дигар барномаҳо.',
        'faq': 'Саволҳои зиёд такроршаванда',
        'faq_what_is': 'Ин чӣ барнома аст?',
        'faq_what_is_ans': 'Sisms Photo — ин каталоги аксҳои шумо бо имкони иловаи ном ва тавсиф, ҷустуҷӯ, тартиб додан ва мубодилаи маълумот тавассути QR-код.',
        'faq_data_safety': 'Оё маълумоти ман бехатар аст?',
        'faq_data_safety_ans': 'Ҳа, ҳамаи аксҳо ва маълумотҳои шумо танҳо дар дастгоҳи шумо нигоҳ дошта мешаванд. Ҳеҷ маълумоте ба интернет фиристода намешавад.',
        'faq_export': 'Чӣ гуна маълумотро ба телефони дигар интиқол додан мумкин?',
        'faq_export_ans': 'Аз экспорти пурра (папка бо аксҳо ва метамаълумот) ё QR-код барои маълумоти матнӣ истифода баред.',
        'faq_language': 'Оё забонро иваз кардан мумкин?',
        'faq_language_ans': 'Ҳа, дар танзимот шумо метавонед забони русӣ ё тоҷикиро интихоб кунед.',
      },
    };
    return dict[app.language]?[key] ?? key;
  }
}
