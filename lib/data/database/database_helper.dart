import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/question.dart';
import '../models/knowledge_point.dart';
import '../models/knowledge_edge.dart';
import '../models/answer_log.dart';
import '../models/review_state.dart';
import '../models/review_session.dart';
import '../models/user_profile.dart';
import '../models/diagnostic_report.dart';
import '../models/chat_message.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'memory_system.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        stem TEXT NOT NULL,
        options_json TEXT NOT NULL,
        correct_index INTEGER NOT NULL,
        explanation TEXT,
        difficulty_b REAL DEFAULT 0.0,
        source_type TEXT,
        distractor_analysis_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_points (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        level INTEGER DEFAULT 0,
        subject_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE knowledge_edges (
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        relation_type TEXT DEFAULT 'related',
        weight REAL DEFAULT 1.0,
        PRIMARY KEY (from_id, to_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE question_kp (
        question_id TEXT NOT NULL,
        kp_id TEXT NOT NULL,
        PRIMARY KEY (question_id, kp_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE answer_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id TEXT NOT NULL,
        session_id INTEGER NOT NULL,
        is_correct INTEGER NOT NULL,
        selected_option INTEGER NOT NULL,
        response_time_ms INTEGER NOT NULL,
        confidence_rating INTEGER DEFAULT 3,
        hesitation_count INTEGER DEFAULT 0,
        timestamp TEXT NOT NULL,
        review_number INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE review_states (
        question_id TEXT PRIMARY KEY,
        easiness_factor REAL DEFAULT 2.5,
        interval_days INTEGER DEFAULT 1,
        review_count INTEGER DEFAULT 0,
        next_review_date TEXT NOT NULL,
        last_qs REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE review_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT,
        total_questions INTEGER DEFAULT 0,
        theta_snapshot REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        theta REAL DEFAULT 0.0,
        stability REAL DEFAULT 30.0,
        total_answers INTEGER DEFAULT 0,
        total_correct INTEGER DEFAULT 0,
        last_study_date TEXT,
        grade TEXT DEFAULT '',
        subject_preference TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE diagnostic_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        report_json TEXT NOT NULL,
        report_type TEXT DEFAULT 'session',
        generated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        context_ref TEXT,
        session_type TEXT DEFAULT 'chat',
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_answer_logs_question ON answer_logs(question_id)');
    await db.execute('CREATE INDEX idx_answer_logs_session ON answer_logs(session_id)');
    await db.execute('CREATE INDEX idx_chat_session_type ON chat_messages(session_type)');

    await db.insert('user_profile', {
      'id': 1, 'theta': 0.0, 'stability': 30.0,
      'total_answers': 0, 'total_correct': 0,
      'grade': '', 'subject_preference': '',
    });

    await _insertSampleData(db);
  }

  Future<void> _insertSampleData(Database db) async {
    final now = DateTime.now().toIso8601String();
    final todayStr = DateTime.now().toIso8601String();

    // Knowledge points
    final kps = [
      {'id': 'kp_redox', 'name': '氧化还原反应', 'description': '涉及电子转移的化学反应', 'level': 1, 'subject_id': 'chemistry'},
      {'id': 'kp_equilibrium', 'name': '化学平衡', 'description': '可逆反应达到动态平衡的状态', 'level': 1, 'subject_id': 'chemistry'},
      {'id': 'kp_ionic', 'name': '离子反应', 'description': '电解质在溶液中的反应', 'level': 1, 'subject_id': 'chemistry'},
      {'id': 'kp_organic', 'name': '有机化学基础', 'description': '碳氢化合物及其衍生物', 'level': 1, 'subject_id': 'chemistry'},
      {'id': 'kp_electrochem', 'name': '电化学', 'description': '化学能与电能的相互转化', 'level': 2, 'subject_id': 'chemistry'},
      {'id': 'kp_periodic', 'name': '元素周期律', 'description': '元素性质随原子序数的周期性变化', 'level': 1, 'subject_id': 'chemistry'},
    ];
    for (final kp in kps) {
      await db.insert('knowledge_points', kp);
    }

    // Knowledge edges
    final edges = [
      {'from_id': 'kp_redox', 'to_id': 'kp_electrochem', 'relation_type': 'prerequisite', 'weight': 0.9},
      {'from_id': 'kp_ionic', 'to_id': 'kp_redox', 'relation_type': 'related', 'weight': 0.7},
      {'from_id': 'kp_ionic', 'to_id': 'kp_equilibrium', 'relation_type': 'related', 'weight': 0.6},
      {'from_id': 'kp_periodic', 'to_id': 'kp_redox', 'relation_type': 'prerequisite', 'weight': 0.5},
    ];
    for (final e in edges) {
      await db.insert('knowledge_edges', e);
    }

    // Sample questions with distractor analysis
    final questions = <Map<String, dynamic>>[
      {
        'id': 'q001', 'stem': '下列物质中，属于强电解质的是',
        'options_json': '["CH₃COOH","NaCl","NH₃·H₂O","C₂H₅OH"]',
        'correct_index': 1, 'explanation': 'NaCl是强电解质，在水溶液中完全电离。CH₃COOH和NH₃·H₂O是弱电解质，C₂H₅OH是非电解质。',
        'difficulty_b': -0.5, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.35,"commonMistakeReason":"混淆弱酸与强电解质"},{"optionIndex":2,"attractiveness":0.25,"commonMistakeReason":"误认为碱都是强电解质"},{"optionIndex":3,"attractiveness":0.1,"commonMistakeReason":"不了解非电解质概念"}]',
        'created_at': now,
      },
      {
        'id': 'q002', 'stem': '在氧化还原反应中，氧化剂',
        'options_json': '["失去电子","得到电子","化合价升高","被氧化"]',
        'correct_index': 1, 'explanation': '氧化剂在反应中得到电子，化合价降低，本身被还原。',
        'difficulty_b': -1.0, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.4,"commonMistakeReason":"混淆氧化剂与还原剂的定义"},{"optionIndex":2,"attractiveness":0.3,"commonMistakeReason":"混淆氧化剂化合价变化方向"},{"optionIndex":3,"attractiveness":0.2,"commonMistakeReason":"混淆被氧化与被还原"}]',
        'created_at': now,
      },
      {
        'id': 'q003', 'stem': '下列关于化学平衡的说法正确的是',
        'options_json': '["平衡时反应停止","平衡时正逆反应速率相等","升温一定使平衡正向移动","加催化剂使平衡移动"]',
        'correct_index': 1, 'explanation': '化学平衡时，正反应速率等于逆反应速率，反应并未停止。升温使平衡向吸热方向移动。催化剂同时改变正逆反应速率，不影响平衡。',
        'difficulty_b': 0.0, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.3,"commonMistakeReason":"误解平衡状态"},{"optionIndex":2,"attractiveness":0.25,"commonMistakeReason":"忽略吸热放热方向"},{"optionIndex":3,"attractiveness":0.2,"commonMistakeReason":"不理解催化剂作用"}]',
        'created_at': now,
      },
      {
        'id': 'q004', 'stem': '甲烷的分子构型是',
        'options_json': '["平面正方形","正三角形","正四面体","直线形"]',
        'correct_index': 2, 'explanation': '甲烷CH₄的碳原子采用sp³杂化，四个C-H键指向正四面体的四个顶点，键角为109.5°。',
        'difficulty_b': -0.8, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.2,"commonMistakeReason":"与XeF₄构型混淆"},{"optionIndex":1,"attractiveness":0.3,"commonMistakeReason":"与BF₃构型混淆"},{"optionIndex":3,"attractiveness":0.1,"commonMistakeReason":"与CO₂构型混淆"}]',
        'created_at': now,
      },
      {
        'id': 'q005', 'stem': '原电池中，负极发生的反应是',
        'options_json': '["还原反应","氧化反应","既有氧化又有还原","不发生反应"]',
        'correct_index': 1, 'explanation': '原电池负极是较活泼金属，失去电子发生氧化反应；正极得到电子发生还原反应。',
        'difficulty_b': 0.2, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.45,"commonMistakeReason":"混淆正负极反应类型"},{"optionIndex":2,"attractiveness":0.15,"commonMistakeReason":"概念模糊"},{"optionIndex":3,"attractiveness":0.05,"commonMistakeReason":"不理解原电池工作原理"}]',
        'created_at': now,
      },
      {
        'id': 'q006', 'stem': '下列离子能在酸性溶液中大量共存的是',
        'options_json': '["Na⁺、K⁺、OH⁻、Cl⁻","Na⁺、K⁺、NO₃⁻、Cl⁻","Fe²⁺、H⁺、NO₃⁻、SO₄²⁻","Ca²⁺、Na⁺、CO₃²⁻、Cl⁻"]',
        'correct_index': 1, 'explanation': 'Na⁺、K⁺、NO₃⁻、Cl⁻在酸性环境下不会发生反应，可以大量共存。OH⁻和CO₃²⁻会与H⁺反应，Fe²⁺在酸性NO₃⁻中会被氧化。',
        'difficulty_b': 0.5, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.2,"commonMistakeReason":"忽略OH⁻与H⁺反应"},{"optionIndex":2,"attractiveness":0.35,"commonMistakeReason":"忽略Fe²⁺在酸性NO₃⁻中被氧化"},{"optionIndex":3,"attractiveness":0.25,"commonMistakeReason":"忽略CO₃²⁻与H⁺反应"}]',
        'created_at': now,
      },
      {
        'id': 'q007', 'stem': '下列有机物中，能发生加成反应的是',
        'options_json': '["甲烷","乙烷","乙烯","丙烷"]',
        'correct_index': 2, 'explanation': '乙烯含有碳碳双键，可以发生加成反应。甲烷、乙烷、丙烷是饱和烃，只能发生取代反应。',
        'difficulty_b': -0.3, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.2,"commonMistakeReason":"混淆取代与加成"},{"optionIndex":1,"attractiveness":0.15,"commonMistakeReason":"混淆饱和烃与不饱和烃"},{"optionIndex":3,"attractiveness":0.1,"commonMistakeReason":"不了解反应类型"}]',
        'created_at': now,
      },
      {
        'id': 'q008', 'stem': '元素周期表中，同一主族从上到下，元素的',
        'options_json': '["原子半径逐渐减小","非金属性逐渐增强","金属性逐渐增强","电负性逐渐增大"]',
        'correct_index': 2, 'explanation': '同一主族从上到下，电子层数增多，原子半径增大，原子核对外层电子的束缚力减弱，金属性增强，非金属性减弱。',
        'difficulty_b': -0.2, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.2,"commonMistakeReason":"与同周期变化规律混淆"},{"optionIndex":1,"attractiveness":0.3,"commonMistakeReason":"混淆金属性与非金属性变化方向"},{"optionIndex":3,"attractiveness":0.2,"commonMistakeReason":"混淆电负性变化规律"}]',
        'created_at': now,
      },
      {
        'id': 'q009', 'stem': '将铁片放入CuSO₄溶液中，观察到的现象是',
        'options_json': '["无明显现象","铁片表面出现红色物质","溶液变为无色","产生气泡"]',
        'correct_index': 1, 'explanation': 'Fe + CuSO₄ → FeSO₄ + Cu，铁比铜活泼，置换出铜（红色）附着在铁片表面，溶液由蓝色变为浅绿色。',
        'difficulty_b': -0.7, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.1,"commonMistakeReason":"不了解活动性顺序"},{"optionIndex":2,"attractiveness":0.25,"commonMistakeReason":"误以为溶液完全变无色"},{"optionIndex":3,"attractiveness":0.15,"commonMistakeReason":"与酸反应混淆"}]',
        'created_at': now,
      },
      {
        'id': 'q010', 'stem': '勒夏特列原理指出，改变平衡条件时，平衡向',
        'options_json': '["正反应方向移动","逆反应方向移动","减弱这种改变的方向移动","增强这种改变的方向移动"]',
        'correct_index': 2, 'explanation': '勒夏特列原理：如果改变影响平衡的一个条件，平衡就向能够减弱这种改变的方向移动。',
        'difficulty_b': 0.3, 'source_type': 'preset',
        'distractor_analysis_json': '[{"optionIndex":0,"attractiveness":0.2,"commonMistakeReason":"过于绝对化"},{"optionIndex":1,"attractiveness":0.15,"commonMistakeReason":"过于绝对化"},{"optionIndex":3,"attractiveness":0.3,"commonMistakeReason":"混淆减弱与增强"}]',
        'created_at': now,
      },
    ];

    for (final q in questions) {
      await db.insert('questions', q);
      await db.insert('review_states', {
        'question_id': q['id'],
        'easiness_factor': 2.5,
        'interval_days': 1,
        'review_count': 0,
        'next_review_date': todayStr,
        'last_qs': 0.0,
      });
    }

    // Question-KP mappings
    final qkps = [
      {'question_id': 'q001', 'kp_id': 'kp_ionic'},
      {'question_id': 'q002', 'kp_id': 'kp_redox'},
      {'question_id': 'q003', 'kp_id': 'kp_equilibrium'},
      {'question_id': 'q004', 'kp_id': 'kp_organic'},
      {'question_id': 'q005', 'kp_id': 'kp_electrochem'},
      {'question_id': 'q005', 'kp_id': 'kp_redox'},
      {'question_id': 'q006', 'kp_id': 'kp_ionic'},
      {'question_id': 'q007', 'kp_id': 'kp_organic'},
      {'question_id': 'q008', 'kp_id': 'kp_periodic'},
      {'question_id': 'q009', 'kp_id': 'kp_redox'},
      {'question_id': 'q010', 'kp_id': 'kp_equilibrium'},
    ];
    for (final qk in qkps) {
      await db.insert('question_kp', qk);
    }
  }

  // ─── Question CRUD ───

  Future<List<Question>> getAllQuestions() async {
    final db = await database;
    final maps = await db.query('questions', orderBy: 'created_at DESC');
    return maps.map(Question.fromDbMap).toList();
  }

  Future<Question?> getQuestionById(String id) async {
    final db = await database;
    final maps = await db.query('questions', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : Question.fromDbMap(maps.first);
  }

  Future<void> insertQuestion(Question q) async {
    final db = await database;
    await db.insert('questions', q.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertQuestions(List<Question> qs) async {
    final db = await database;
    final batch = db.batch();
    for (final q in qs) {
      batch.insert('questions', q.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateQuestion(Question q) async {
    final db = await database;
    await db.update('questions', q.toDbMap(), where: 'id = ?', whereArgs: [q.id]);
  }

  Future<void> deleteQuestion(String id) async {
    final db = await database;
    await db.delete('questions', where: 'id = ?', whereArgs: [id]);
    await db.delete('review_states', where: 'question_id = ?', whereArgs: [id]);
    await db.delete('question_kp', where: 'question_id = ?', whereArgs: [id]);
  }

  Future<int> getQuestionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM questions');
    return result.first['cnt'] as int? ?? 0;
  }

  Future<List<Question>> getQuestionsByKnowledgePoint(String kpId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT q.* FROM questions q
      INNER JOIN question_kp qk ON q.id = qk.question_id
      WHERE qk.kp_id = ?
    ''', [kpId]);
    return maps.map(Question.fromDbMap).toList();
  }

  // ─── KnowledgePoint CRUD ───

  Future<List<KnowledgePoint>> getAllKnowledgePoints() async {
    final db = await database;
    final maps = await db.query('knowledge_points');
    return maps.map(KnowledgePoint.fromDbMap).toList();
  }

  Future<void> insertKnowledgePoint(KnowledgePoint kp) async {
    final db = await database;
    await db.insert('knowledge_points', kp.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<KnowledgePoint>> getKnowledgePointsForQuestion(String questionId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT kp.* FROM knowledge_points kp
      INNER JOIN question_kp qk ON kp.id = qk.kp_id
      WHERE qk.question_id = ?
    ''', [questionId]);
    return maps.map(KnowledgePoint.fromDbMap).toList();
  }

  Future<Map<String, List<Question>>> getQuestionsGroupedByKP() async {
    final kps = await getAllKnowledgePoints();
    final result = <String, List<Question>>{};
    for (final kp in kps) {
      result[kp.name] = await getQuestionsByKnowledgePoint(kp.id);
    }
    return result;
  }

  // ─── KnowledgeEdge ───

  Future<List<String>> getKnowledgePointIdsForQuestion(String questionId) async {
    final db = await database;
    final maps = await db.query('question_kp',
        where: 'question_id = ?', whereArgs: [questionId]);
    return maps.map((m) => m['kp_id'] as String).toList();
  }

  Future<List<KnowledgeEdge>> getAllEdges() async {
    final db = await database;
    final maps = await db.query('knowledge_edges');
    return maps.map(KnowledgeEdge.fromDbMap).toList();
  }

  Future<void> insertEdge(KnowledgeEdge edge) async {
    final db = await database;
    await db.insert('knowledge_edges', edge.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── QuestionKP ───

  Future<void> linkQuestionToKP(String questionId, String kpId) async {
    final db = await database;
    await db.insert('question_kp', {'question_id': questionId, 'kp_id': kpId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // ─── AnswerLog ───

  Future<int> insertAnswerLog(AnswerLog log) async {
    final db = await database;
    return db.insert('answer_logs', log.toDbMap());
  }

  Future<List<AnswerLog>> getAnswerLogsBySession(int sessionId) async {
    final db = await database;
    final maps = await db.query('answer_logs', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'timestamp ASC');
    return maps.map(AnswerLog.fromDbMap).toList();
  }

  Future<List<AnswerLog>> getAnswerLogsByQuestion(String questionId) async {
    final db = await database;
    final maps = await db.query('answer_logs', where: 'question_id = ?', whereArgs: [questionId], orderBy: 'timestamp DESC');
    return maps.map(AnswerLog.fromDbMap).toList();
  }

  Future<List<AnswerLog>> getRecentAnswerLogs(int limit) async {
    final db = await database;
    final maps = await db.query('answer_logs', orderBy: 'timestamp DESC', limit: limit);
    return maps.map(AnswerLog.fromDbMap).toList();
  }

  // ─── ReviewState ───

  Future<ReviewState?> getReviewState(String questionId) async {
    final db = await database;
    final maps = await db.query('review_states', where: 'question_id = ?', whereArgs: [questionId]);
    return maps.isEmpty ? null : ReviewState.fromDbMap(maps.first);
  }

  Future<void> upsertReviewState(ReviewState state) async {
    final db = await database;
    await db.insert('review_states', state.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReviewState>> getDueReviewStates(DateTime before) async {
    final db = await database;
    final maps = await db.query('review_states',
        where: 'next_review_date <= ?', whereArgs: [before.toIso8601String()]);
    return maps.map(ReviewState.fromDbMap).toList();
  }

  Future<List<ReviewState>> getAllReviewStates() async {
    final db = await database;
    final maps = await db.query('review_states');
    return maps.map(ReviewState.fromDbMap).toList();
  }

  // ─── ReviewSession ───

  Future<int> insertSession(ReviewSession session) async {
    final db = await database;
    return db.insert('review_sessions', session.toDbMap());
  }

  Future<void> updateSession(int id, {DateTime? endTime, int? totalQuestions, double? thetaSnapshot}) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (endTime != null) updates['end_time'] = endTime.toIso8601String();
    if (totalQuestions != null) updates['total_questions'] = totalQuestions;
    if (thetaSnapshot != null) updates['theta_snapshot'] = thetaSnapshot;
    if (updates.isNotEmpty) {
      await db.update('review_sessions', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<List<ReviewSession>> getAllSessions() async {
    final db = await database;
    final maps = await db.query('review_sessions', orderBy: 'start_time DESC');
    return maps.map(ReviewSession.fromDbMap).toList();
  }

  // ─── UserProfile ───

  Future<UserProfile> getUserProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', where: 'id = 1');
    if (maps.isEmpty) return const UserProfile();
    return UserProfile.fromDbMap(maps.first);
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    final db = await database;
    await db.update('user_profile', profile.toDbMap(), where: 'id = 1');
  }

  // ─── DiagnosticReport ───

  Future<int> insertReport(DiagnosticReport report) async {
    final db = await database;
    return db.insert('diagnostic_reports', report.toDbMap());
  }

  Future<List<DiagnosticReport>> getReportsByType(String type) async {
    final db = await database;
    final maps = await db.query('diagnostic_reports',
        where: 'report_type = ?', whereArgs: [type], orderBy: 'generated_at DESC');
    return maps.map(DiagnosticReport.fromDbMap).toList();
  }

  Future<List<DiagnosticReport>> getAllReports() async {
    final db = await database;
    final maps = await db.query('diagnostic_reports', orderBy: 'generated_at DESC');
    return maps.map(DiagnosticReport.fromDbMap).toList();
  }

  Future<DiagnosticReport?> getReportById(int id) async {
    final db = await database;
    final maps = await db.query('diagnostic_reports', where: 'id = ?', whereArgs: [id]);
    return maps.isEmpty ? null : DiagnosticReport.fromDbMap(maps.first);
  }

  // ─── ChatMessage ───

  Future<int> insertChatMessage(ChatMessage msg) async {
    final db = await database;
    return db.insert('chat_messages', msg.toDbMap());
  }

  Future<List<ChatMessage>> getChatHistory({String sessionType = 'chat', int? limit}) async {
    final db = await database;
    final maps = await db.query('chat_messages',
        where: 'session_type = ?', whereArgs: [sessionType],
        orderBy: 'timestamp ASC', limit: limit);
    return maps.map(ChatMessage.fromDbMap).toList();
  }

  Future<void> clearChatHistory({String sessionType = 'chat'}) async {
    final db = await database;
    await db.delete('chat_messages', where: 'session_type = ?', whereArgs: [sessionType]);
  }

  // ─── Statistics ───

  Future<Map<String, double>> getWeakKnowledgePoints({int limit = 5}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT kp.name,
        CAST(SUM(CASE WHEN al.is_correct = 0 THEN 1 ELSE 0 END) AS REAL) /
        CAST(COUNT(*) AS REAL) AS error_rate
      FROM answer_logs al
      INNER JOIN question_kp qk ON al.question_id = qk.question_id
      INNER JOIN knowledge_points kp ON qk.kp_id = kp.id
      GROUP BY kp.name
      HAVING COUNT(*) >= 2
      ORDER BY error_rate DESC
      LIMIT ?
    ''', [limit]);
    return {for (final r in result) r['name'] as String: (r['error_rate'] as num).toDouble()};
  }

  // ─── Export / Import ───

  Future<Map<String, dynamic>> exportAll() async {
    final db = await database;
    return {
      'questions': await db.query('questions'),
      'knowledge_points': await db.query('knowledge_points'),
      'knowledge_edges': await db.query('knowledge_edges'),
      'question_kp': await db.query('question_kp'),
      'answer_logs': await db.query('answer_logs'),
      'review_states': await db.query('review_states'),
      'review_sessions': await db.query('review_sessions'),
      'user_profile': await db.query('user_profile'),
      'diagnostic_reports': await db.query('diagnostic_reports'),
      'chat_messages': await db.query('chat_messages'),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in ['chat_messages', 'diagnostic_reports', 'answer_logs', 'review_states',
          'review_sessions', 'question_kp', 'knowledge_edges', 'knowledge_points', 'questions', 'user_profile']) {
        await txn.delete(table);
      }
      for (final entry in data.entries) {
        final list = entry.value as List;
        for (final row in list) {
          await txn.insert(entry.key, Map<String, dynamic>.from(row as Map),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
