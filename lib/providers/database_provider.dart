import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/database_helper.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});
