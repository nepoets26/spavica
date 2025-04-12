import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Thêm class singleton mới
class LastFetchTimeManager {
  static final LastFetchTimeManager _instance = LastFetchTimeManager._internal();
  DateTime _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const String _lastFetchTimeKey = 'last_fetch_time';

  factory LastFetchTimeManager() {
    return _instance;
  }

  LastFetchTimeManager._internal();

  DateTime get lastFetchTime => _lastFetchTime;
  set lastFetchTime(DateTime value) {
    _lastFetchTime = value;
    _saveLastFetchTime();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastFetchTimeKey);
    if (timestamp != null) {
      _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  Future<void> _saveLastFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastFetchTimeKey, _lastFetchTime.millisecondsSinceEpoch);
  }
}

class VideoCardService {
  VideoCardService() : _firestore = FirebaseFirestore.instance {
    LastFetchTimeManager().initialize();
  }

  // Private constructor

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Thêm constant cho cache config
  static const cacheField = 'updatedAt';

  // Thêm biến để kiểm tra trạng thái cache

  // Thêm Map để lưu cache với key là id
  Map<String, VideoCard> _cachedCardsMap = {};

  // Thêm biến thời gian cục bộ
  // DateTime _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
  // static const String _lastFetchTimeKey = 'last_fetch_time';



  Stream<Map<String, DueCardInfo>> getDueCardsInfoForDecks() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value({});
    }

    return getVideoCardsForCache().map((allCards) {
      Map<String, DueCardInfo> dueCardsInfo = {};
      final now = DateTime.now();

      for (var card in _cachedCardsMap.values) {
        if (card.deletedAt == null && card.dueDate.isBefore(now)) {
          final deckId = card.deckId;
          final interval = card.interval;

          if (deckId != null) {
            if (!dueCardsInfo.containsKey(deckId)) {
              dueCardsInfo[deckId] = DueCardInfo();
            }

            if (interval <= 7) {
              dueCardsInfo[deckId]!.shortTermCount++;
            } else if (interval <= 29) {
              dueCardsInfo[deckId]!.mediumTermCount++;
            } else if (interval <= 359) {
              dueCardsInfo[deckId]!.longTermCount++;
            } else if (interval <= 1799) {
              dueCardsInfo[deckId]!.extralongTermCount++;
            } else if (interval <= 3599) {
              dueCardsInfo[deckId]!.ultralongTermCount++;
            } else {
              dueCardsInfo[deckId]!.infinitelylongTermCount++;
            }
          }
        }
      }

      return dueCardsInfo;
    });
  }

  Stream<List<VideoCard>> getDueVideoCards(String deckId) {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    return getVideoCardsForCache().map((allCards) {
      final now = DateTime.now();

      updateOverdueInCache();

      return _cachedCardsMap.values
        .where((card) => card.deletedAt == null && card.deckId == deckId && card.dueDate.isBefore(now))
        .toList()
        ;
    });
  }
  Stream<List<VideoCard>> getTodayReviewedCards() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return getVideoCardsForCache().map((cards) {
      List<VideoCard> todayCards = _cachedCardsMap.values
        .where((card) => card.deletedAt == null && card.reviewDates.any((reviewDate) =>
            reviewDate.isAfter(startOfDay) && reviewDate.isBefore(endOfDay)))
        .toList();

      todayCards.sort((a, b) {
        final aLatestReview = a.reviewDates.isEmpty ? a.createdAt : a.reviewDates.last;
        final bLatestReview = b.reviewDates.isEmpty ? b.createdAt : b.reviewDates.last;
        return bLatestReview.compareTo(aLatestReview);
      });

      return todayCards;
    });
  }

  Future<void> addVideoCard({
    required String videoId,
    required String videoTitle,
    required double startTime,
    required double endTime,
    required String answer,
    String? deckId,
    double videoSpeed = 1.0,
    int overdue = 0
  }) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to add video cards');
      }
      final userEmail = _auth.currentUser!.email!;
      final now = Timestamp.now();
      
      final cardData = {
        'videoId': videoId,
        'videoTitle': videoTitle,
        'startTime': startTime,
        'endTime': endTime,
        'answer': answer,
        'deckId': deckId,
        'videoSpeed': videoSpeed,
        'overdue': overdue,
        'createdAt': now,
        'reviewDates': [],
        'ratings': [],
        'interval': 0,
        'dueDate': now,
        'updatedAt': now,
        'updatedBy': LastFetchTimeManager().lastFetchTime.toIso8601String(),
      };

      // Thêm card vào Firestore và lấy document reference
      final docRef = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('video_cards')
          .add(cardData);

      // Tạo VideoCard object và thêm vào cache
      final newCard = VideoCard.fromFirestore(cardData, docRef.id);
      _cachedCardsMap[docRef.id] = newCard;

    } catch (e, stackTrace) {
      print('Error in VideoCardService.addVideoCard: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  Stream<List<VideoCard>> searchVideoCards(String query) {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    final lowercaseQuery = query.toLowerCase();

    return getVideoCardsForCache().map((allCards) {
      return allCards.where((card) =>
          card.deletedAt == null &&
          (card.videoId.toLowerCase().contains(lowercaseQuery) ||
          card.videoTitle.toLowerCase().contains(lowercaseQuery) ||
          card.answer.toLowerCase().contains(lowercaseQuery))
      ).toList();
    });
  }

  // Thêm phương thức mới để xử lý cache
  Stream<List<VideoCard>> getVideoCardsForCache() async* {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      yield [];
      return;
    }

    if (_cachedCardsMap.isNotEmpty) {
      //print('📦 Trả về dữ liệu từ memory cache');
      updateOverdueInCache();
      yield _cachedCardsMap.values.toList();
      return;
    }

    try {
      final cards = await _fetchCardsFromFirestore();
      _cachedCardsMap = Map.fromEntries(cards.map((card) => MapEntry(card.id!, card)));
      updateOverdueInCache();
      yield _cachedCardsMap.values.toList();
    } catch (e) {
      print('Error getting cached documents: $e');
      yield [];
    }
  }

  // Thêm method để đảm bảo cache document tồn tại


  // Thêm method để fetch từ Firestore
  Future<List<VideoCard>> _fetchCardsFromFirestore() async {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return [];
    }

    final userEmail = _auth.currentUser!.email!;
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .doc(userEmail)
        .collection('video_cards');

    final lastFetchManager = LastFetchTimeManager();
    
    try {
      final now = DateTime.now();
      final difference = now.difference(lastFetchManager.lastFetchTime).inDays;
      var cachedDocs = await query.get(const GetOptions(source: Source.cache));
      
      final QuerySnapshot<Map<String, dynamic>> serverDocs;
      
      // Nếu thời gian kể từ lần fetch trước lớn hơn 30 ngày, lấy tất cả dữ liệu từ server
      if (cachedDocs.docs.isEmpty ||difference > 30) {
        serverDocs = await query.get(const GetOptions(source: Source.serverAndCache));
        //print('📦 Đã quá 30 ngày, lấy tất cả dữ liệu từ server');
      } else {
        // Ngược lại, chỉ lấy dữ liệu đã được cập nhật từ lần fetch trước
        serverDocs = await query
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(lastFetchManager.lastFetchTime))
          .where('updatedBy', isNotEqualTo: lastFetchManager.lastFetchTime.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));
        //print('📦 Lấy dữ liệu mới từ server (dưới 30 ngày)');
      }
      
       cachedDocs = await query.get(const GetOptions(source: Source.cache));

      //print('📦 Số lượng documents mới từ server: ${serverDocs.docs.length}');

      // Cập nhật _lastFetchTime
      lastFetchManager.lastFetchTime = DateTime.now();

      final newCards = cachedDocs.docs.map((doc) {
        try {
          return VideoCard.fromFirestore(doc.data(), doc.id);
        } catch (e) {
          print('Error parsing video card ${doc.id}: $e');
          return null;
        }
      }).whereType<VideoCard>().toList();

      // Cập nhật cache với các card mới
      for (var card in newCards) {
        _cachedCardsMap[card.id!] = card;
      }

      return _cachedCardsMap.values.toList();
    } catch (e) {
      print('Error getting cached documents: $e');
      return [];
    }
  }

  // Thêm method để cập nhật cache timestamp khi có thay đổi


  // Sửa lại phương thức getVideoCardsInDeck để sử dụng cache
  Stream<List<VideoCard>> getVideoCardsInDeck(String deckId) {
    return getVideoCardsForCache().map((allCards) {
      return _cachedCardsMap.values
        .where((card) => card.deletedAt == null && card.deckId == deckId)
        .toList();
    });
  }

  Future<void> updateVideoCardReview(String cardId, int rating, double newSpeed, int newInterval) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to update video cards');
      }

      final card = _cachedCardsMap[cardId];
      if (card == null) {
        throw Exception('Card not found in cache');
      }

      final now = Timestamp.now();
      final List<DateTime> newReviewDates = List.from(card.reviewDates)..add(now.toDate());
      final List<int> newRatings = List.from(card.ratings)..add(rating);
      final newDueDate = now.toDate().add(Duration(days: newInterval));

      // Tạo card mới với các giá trị đã cập nhật
      final updatedCard = card.copyWith(
        reviewDates: newReviewDates,
        ratings: newRatings,
        interval: newInterval,
        dueDate: newDueDate,
        videoSpeed: newSpeed,
        updatedAt: now.toDate(),
        updatedBy: LastFetchTimeManager().lastFetchTime.toIso8601String(),
      );

      // Cập nhật Firestore
      final cardRef = _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .doc(cardId);

      await cardRef.update(updatedCard.toMap());

      // Cập nhật cache memory
      //_cachedCardsMap[cardId] = updatedCard;

    } catch (e) {
      print('Error in updateVideoCardReview: $e');
      rethrow;
    }
  }
  Future<void> deleteVideoCardTemp(String cardId) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to temporarily delete video cards');
      }

      final userEmail = _auth.currentUser!.email!;
      final now = Timestamp.now();
      final cardRef = _firestore
          .collection('users')
          .doc(userEmail)
          .collection('video_cards')
          .doc(cardId);

      // Lấy card từ cache
      final card = _cachedCardsMap[cardId];
      if (card == null) {
        throw Exception('Card not found in cache');
      }

      // Cập nhật Firestore với trường deletedAt
      await cardRef.update({
        'deletedAt': now,
        'updatedAt': now,
        'updatedBy': LastFetchTimeManager().lastFetchTime.toIso8601String(),
      });

      // Cập nhật cache với card đã thêm trường deletedAt
      final updatedCard = card.copyWith(
        deletedAt: now.toDate(),
        updatedAt: now.toDate(),
        updatedBy: LastFetchTimeManager().lastFetchTime.toIso8601String(),
      );
      _cachedCardsMap[cardId] = updatedCard;

      print('Video card temporarily deleted successfully: $cardId');
    } catch (e) {
      print('Error in deleteVideoCardTemp: $e');
      rethrow;
    }
  }
  Future<void> deleteVideoCard(String cardId) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to delete video cards');
      }

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .doc(cardId)
          .delete();

      // Xóa từ cache memory và cập nhật timestamp

        _cachedCardsMap.remove(cardId);


      print('Video card deleted successfully: $cardId');
    } catch (e) {
      print('Error in deleteVideoCard: $e');
      rethrow;
    }
  }
  Stream<List<VideoCard>> getTodayVideoCards() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return getVideoCardsForCache().map((allCards) {
      List<VideoCard> todayCards = _cachedCardsMap.values
        .where((card) => card.deletedAt == null && card.createdAt.isAfter(startOfDay))
        .toList();

      // Sắp xếp theo thời gian tạo mới nhất
      todayCards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return todayCards;
    });
  }
  Future<void> updateVideoCard(VideoCard card) async {
    try {
      final userEmail = _auth.currentUser!.email!;
      final cardRef = _firestore
          .collection('users')
          .doc(userEmail)
          .collection('video_cards')
          .doc(card.id);

      // Tạo card mới với updatedAt là thời gian hiện tại
      final updatedCard = card.copyWith(
        updatedAt: Timestamp.now().toDate(),
        updatedBy: LastFetchTimeManager().lastFetchTime.toIso8601String(),
      );

      // Cập nhật lên Firestore
      await cardRef.update(updatedCard.toMap());

      // Cập nhật vào cache
      _cachedCardsMap[card.id!] = updatedCard;
    } catch (e) {
      print('❌ Error in updateVideoCard: $e');
      throw e;
    }
  }

  // Thêm method để clear cache khi cần
  void clearCache() {
    _cachedCardsMap.clear();

  }

  // Thêm method để cập nhật cache


  // Thêm method để rollback cache
  void rollbackCardInCache(VideoCard card) {

      _cachedCardsMap[card.id!] = card;

  }

  // Thêm method mới để update overdue trong memory cache
  void updateOverdueInCache() {


    final now = DateTime.now();

    _cachedCardsMap = Map.fromEntries(
      _cachedCardsMap.entries.map((entry) {
        final card = entry.value;
        final difference = now.difference(card.dueDate).inDays;
        final newOverdue = difference > 0 ? difference : 0;

        if (newOverdue != card.overdue) {
          // Chỉ tạo card mới nếu overdue thay đổi
          return MapEntry(
            entry.key,
            card.copyWith(overdue: newOverdue)
          );
        }
        return entry;
      })
    );
  }

  Stream<List<VideoCard>> getDeletedCards() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    return getVideoCardsForCache().map((allCards) {
      List<VideoCard> deletedCards = _cachedCardsMap.values
        .where((card) => card.deletedAt != null)
        .toList();

      // Sắp xếp theo thời gian xóa gần đây nhất
      deletedCards.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

      return deletedCards;
    });
  }

  Future<void> restoreCard(String cardId) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to restore video cards');
      }

      // Lấy card từ cache
      final card = _cachedCardsMap[cardId];
      if (card == null) {
        throw Exception('Card not found in cache');
      }

      final userEmail = _auth.currentUser!.email!;
      final now = Timestamp.now();
      final cardRef = _firestore
          .collection('users')
          .doc(userEmail)
          .collection('video_cards')
          .doc(cardId);

      // Cập nhật Firestore - đặt deletedAt thành null
      await cardRef.update({
        'deletedAt': null,
        'updatedAt': now,
        'updatedBy': LastFetchTimeManager().lastFetchTime.toIso8601String(),
      });

      // Cập nhật cache với card đã khôi phục (deletedAt = null)
      final restoredCard = card.copyWith(
        deletedAt: null,
        updatedAt: now.toDate(),
        updatedBy: LastFetchTimeManager().lastFetchTime.toIso8601String(),
      );
      _cachedCardsMap[cardId] = restoredCard;

      print('Video card restored successfully: $cardId');
    } catch (e) {
      print('Error in restoreCard: $e');
      rethrow;
    }
  }

  VideoCard? getCardFromCache(String cardId) {
    return _cachedCardsMap[cardId];
  }
}


// Cập nhật model VideoCard để thêm các giá trị mặc định và xử lý null
class VideoCard {
  final String? id;
  final String videoId;
  final String videoTitle;
  final double startTime;
  final double endTime;
  final String answer;
  final String? deckId;
  final String? deckName;
  final DateTime createdAt;
  final List<DateTime> reviewDates;
  final List<int> ratings;
  final int interval;
  final int overdue;
  final DateTime dueDate;
  final double videoSpeed;
  final double maxVideoSpeed;
  final DateTime updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;

  VideoCard({
    this.id,
    required this.videoId,
    required this.videoTitle,
    required this.startTime,
    required this.endTime,
    required this.answer,
    this.deckId,
    this.deckName,
    required this.createdAt,
    required this.reviewDates,
    required this.ratings,
    required this.interval,
    required this.overdue,
    required this.dueDate,
    this.videoSpeed = 1.0,
    this.maxVideoSpeed = 2.0,
    required this.updatedAt,
    this.updatedBy,
    this.deletedAt,
  });

  // Thêm factory constructor để xử lý dữ liệu từ Firestore
  factory VideoCard.fromFirestore(Map<String, dynamic> data, String? id) {
    try {
      // Xử lý reviewDates một cách an toàn hơn
      List<DateTime> parsedReviewDates = [];
      if (data['reviewDates'] != null) {
        final reviewDatesList = data['reviewDates'] as List<dynamic>;
        parsedReviewDates = reviewDatesList.map((date) {
          if (date is Timestamp) {
            return date.toDate();
          }
          return DateTime.now();
        }).toList();
      }

      // Xử lý ratings một cách an toàn hơn
      List<int> parsedRatings = [];
      if (data['ratings'] != null) {
        final ratingsList = data['ratings'] as List<dynamic>;
        parsedRatings = ratingsList.map((rating) {
          if (rating is int) {
            return rating;
          }
          return 0;
        }).toList();
      }

      return VideoCard(
        id: id,
        videoId: data['videoId']?.toString() ?? '',
        videoTitle: data['videoTitle']?.toString() ?? '',
        startTime: _parseDouble(data['startTime']) ?? 0.0,
        endTime: _parseDouble(data['endTime']) ?? 0.0,
        answer: data['answer']?.toString() ?? '',
        deckId: data['deckId']?.toString(),
        deckName: data['deckName']?.toString(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        reviewDates: parsedReviewDates,
        ratings: parsedRatings,
        interval: data['interval'] as int? ?? 0,
        overdue: data['overdue'] as int? ?? 0,
        dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        videoSpeed: _parseDouble(data['videoSpeed']) ?? 1.0,
        maxVideoSpeed: _parseDouble(data['maxVideoSpeed']) ?? 2.0,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedBy: data['updatedBy']?.toString(),
        deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      print('Error parsing VideoCard from Firestore: $e');
      // Return a default VideoCard in case of parsing errors
      return VideoCard(
        id: id,
        videoId: '',
        videoTitle: '',
        startTime: 0.0,
        endTime: 0.0,
        answer: '',
        createdAt: DateTime.now(),
        reviewDates: [],
        ratings: [],
        interval: 0,
        overdue:0,
        dueDate: DateTime.now(),
        updatedAt: DateTime.now(),
        updatedBy: null,
        deletedAt: null,
      );
    }
  }
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Thêm method để chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'videoTitle': videoTitle,
      'startTime': startTime,
      'endTime': endTime,
      'answer': answer,
      'deckId': deckId,
      'deckName': deckName,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewDates': reviewDates.map((date) => Timestamp.fromDate(date)).toList(),
      'ratings': ratings,
      'interval': interval,
      'overdue':overdue,
      'dueDate': Timestamp.fromDate(dueDate),
      'videoSpeed': videoSpeed,
      'maxVideoSpeed': maxVideoSpeed,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'startTime': startTime,
      'endTime': endTime,
      'answer': answer,
      'deckId': deckId,
      'deckName': deckName,
      'createdAt': createdAt.toIso8601String(),
      'reviewDates': reviewDates.map((date) => date.toIso8601String()).toList(),
      'ratings': ratings,
      'interval': interval,
      'overdue':overdue,
      'dueDate': dueDate.toIso8601String(),
      'videoSpeed': videoSpeed,
      'maxVideoSpeed': maxVideoSpeed,
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
  VideoCard copyWith({
    String? id,
    String? videoId,
    String? videoTitle,
    double? startTime,
    double? endTime,
    String? answer,
    String? deckId,
    String? deckName,
    DateTime? createdAt,
    List<DateTime>? reviewDates,
    List<int>? ratings,
    int? interval,
    int? overdue,
    DateTime? dueDate,
    double? videoSpeed,
    double? maxVideoSpeed,
    DateTime? updatedAt,
    String? updatedBy,
    DateTime? deletedAt,
  }) {
    return VideoCard(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      videoTitle: videoTitle ?? this.videoTitle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      answer: answer ?? this.answer,
      deckId: deckId ?? this.deckId,
      deckName: deckName ?? this.deckName,
      createdAt: createdAt ?? this.createdAt,
      reviewDates: reviewDates ?? this.reviewDates,
      ratings: ratings ?? this.ratings,
      interval: interval ?? this.interval,
      overdue: overdue ?? this.overdue,

      dueDate: dueDate ?? this.dueDate,
      videoSpeed: videoSpeed ?? this.videoSpeed,
      maxVideoSpeed: maxVideoSpeed ?? this.maxVideoSpeed,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
class DueCardInfo {
  int shortTermCount = 0;  // interval <= 7
  int mediumTermCount = 0; // 7 < interval <= 30
  int longTermCount = 0;   // 31 < interval <= 299
  int extralongTermCount = 0; // 300 < interval <= 1499
  int ultralongTermCount = 0; // 1500 < interval <= 2999
  int infinitelylongTermCount = 0; // interval > 3000

  int get totalCount => shortTermCount + mediumTermCount + longTermCount + 
                        extralongTermCount + ultralongTermCount + infinitelylongTermCount;
}