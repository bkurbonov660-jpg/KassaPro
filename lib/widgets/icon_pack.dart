import 'package:flutter/material.dart';

const iconMap = {
  'target': Icons.track_changes,
  'money': Icons.attach_money,
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
  'phone': Icons.smartphone_outlined,
  'laptop': Icons.laptop_mac_outlined,
  'plane': Icons.flight_outlined,
  'globe': Icons.public,
  'gift': Icons.card_giftcard_outlined,
  'ring': Icons.ring_volume_outlined,
  'camera': Icons.camera_alt_outlined,
  'watch': Icons.watch_outlined,
  'game': Icons.sports_esports_outlined,
  'diamond': Icons.diamond_outlined,
  'grad': Icons.school_outlined,
  'briefcase': Icons.work_outline,
  'heart': Icons.favorite_border,
  'star': Icons.star_border,
};
const iconKeys = ['target','money','home','car','phone','laptop','plane','globe','gift','ring','camera','watch','game','diamond','grad','briefcase','heart','star'];
IconData iconFor(String k) => iconMap[k] ?? Icons.track_changes;
