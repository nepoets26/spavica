import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoCardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }
    return 0.0;
  }
  Future<void> updateOverdueForDeck(String deckId) async {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      throw Exception('User must be logged in to update cards');
    }

    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Get all cards in the deck
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .where('deckId', isEqualTo: deckId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final dueDate = (data['dueDate'] as Timestamp).toDate();

        // Calculate overdue days
        final difference = now.difference(dueDate).inDays;
        final overdue = difference > 0 ? difference : 0;

        // Update the document with new overdue value
        batch.update(doc.reference, {'overdue': overdue});
      }

      // Commit all updates in a single batch
      await batch.commit();
    } catch (e) {
      print('Error updating overdue values: $e');
      rethrow;
    }
  }

  Stream<Map<String, DueCardInfo>> getDueCardsInfoForDecks() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value({});
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.email)
        .collection('video_cards')
        .where('dueDate', isLessThanOrEqualTo: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      Map<String, DueCardInfo> dueCardsInfo = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final deckId = data['deckId'] as String?;
        final interval = data['interval'] as int? ?? 0;

        if (deckId != null) {
          if (!dueCardsInfo.containsKey(deckId)) {
            dueCardsInfo[deckId] = DueCardInfo();
          }

          if (interval <= 7) {
            dueCardsInfo[deckId]!.shortTermCount++;
          } else if (interval <= 30) {
            dueCardsInfo[deckId]!.mediumTermCount++;
          } else {
            dueCardsInfo[deckId]!.longTermCount++;
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

    try {
      return _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .where('deckId', isEqualTo: deckId)
          .where('dueDate', isLessThanOrEqualTo: Timestamp.now())
          .orderBy('dueDate')
          .snapshots()
          .asyncMap((snapshot) async {
        List<VideoCard> cards = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          cards.add(VideoCard.fromFirestore(data, doc.id));
        }
        return cards;
      }).handleError((error) {
        print('Error in getDueVideoCards stream: $error');
        return [];
      });
    } catch (e) {
      print('Error setting up getDueVideoCards stream: $e');
      return Stream.value([]);
    }
  }
  Stream<List<VideoCard>> getTodayReviewedCards() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      return _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .snapshots()
          .map((snapshot) {
        List<VideoCard> cards = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final List<Timestamp> reviewDates = (data['reviewDates'] as List?)
              ?.map((item) => item as Timestamp)
              .toList() ?? [];

          // Kiểm tra xem có review nào trong ngày hôm nay không
          bool hasReviewToday = reviewDates.any((timestamp) {
            final reviewDate = timestamp.toDate();
            return reviewDate.isAfter(startOfDay) &&
                reviewDate.isBefore(endOfDay);
          });

          if (hasReviewToday) {
            cards.add(VideoCard.fromFirestore(data, doc.id));
          }
        }

        // Sắp xếp cards theo thời gian review mới nhất
        cards.sort((a, b) {
          final aLatestReview = a.reviewDates.isEmpty ? a.createdAt : a.reviewDates.last;
          final bLatestReview = b.reviewDates.isEmpty ? b.createdAt : b.reviewDates.last;
          return bLatestReview.compareTo(aLatestReview);
        });

        return cards;
      })
          .handleError((error) {
        print('Error in getTodayReviewedCards stream: $error');
        return <VideoCard>[];
      });
    } catch (e) {
      print('Error setting up getTodayReviewedCards stream: $e');
      return Stream.value([]);
    }
  }

  Future<void> addVideoCard({
    required String videoId,
    required String videoTitle,
    required double startTime,
    required double endTime,
    required String answer,
    String? deckId,
    double videoSpeed = 1.0,
    int overdue=0

  }) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to add video cards');
      }
      final userEmail = _auth.currentUser!.email!;
      final cardData = {
        'videoId': videoId,
        'videoTitle': videoTitle,
        'startTime': startTime,
        'endTime': endTime,
        'answer': answer,
        'deckId': deckId,
        'videoSpeed': videoSpeed,
        'overdue':overdue,
        'createdAt': FieldValue.serverTimestamp(),
        'reviewDates': [],
        'ratings': [],
        'interval': 0,
        'dueDate': FieldValue.serverTimestamp(),
      };

      final cardRef = await _firestore
          .collection('users')
          .doc(userEmail)
          .collection('video_cards')
          .add(cardData);

      if (deckId != null) {
        await _firestore
            .collection('users')
            .doc(userEmail)
            .collection('decks')
            .doc(deckId)
            .update({
          'cardRefs': FieldValue.arrayUnion([cardRef.id])
        });
      }
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

    try {
      final lowercaseQuery = query.toLowerCase();

      return _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .snapshots()
          .map((snapshot) {
        List<VideoCard> cards = [];
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            final card = VideoCard.fromFirestore(data, doc.id);

            if (card.videoId.toLowerCase().contains(lowercaseQuery) ||
                card.videoTitle.toLowerCase().contains(lowercaseQuery) ||
                card.answer.toLowerCase().contains(lowercaseQuery)
                ) {
              cards.add(card);
            }
          } catch (e) {
            print('Error processing document ${doc.id}: $e');
            continue;
          }
        }
        return cards;
      })
          .handleError((error) {
        print('Error in searchVideoCards stream: $error');
        return <VideoCard>[];
      });
    } catch (e) {
      print('Error setting up searchVideoCards stream: $e');
      return Stream.value([]);
    }
  }


  Stream<List<VideoCard>> getVideoCardsInDeck(String deckId) {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .where('deckId', isEqualTo: deckId)  // Filter ngay từ database
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        List<VideoCard> cards = [];
        for (var doc in snapshot.docs) {
          cards.add(VideoCard.fromFirestore(doc.data(), doc.id));
        }
        return cards;
      }).handleError((error) {
        print('Error in getVideoCardsInDeck stream: $error');
        return [];
      });
    } catch (e) {
      print('Error setting up getVideoCardsInDeck stream: $e');
      return Stream.value([]);
    }
  }
  Future<void> updateVideoCardReview(String cardId, int rating, double newSpeed, int newInterval) async {
    try {
      if (_auth.currentUser == null || _auth.currentUser!.email == null) {
        throw Exception('User must be logged in to update video cards');
      }

      final cardRef = _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .doc(cardId);

      final cardDoc = await cardRef.get();
      if (!cardDoc.exists) {
        throw Exception('Card not found');
      }

      final cardData = cardDoc.data() as Map<String, dynamic>;
      final VideoCard card = VideoCard.fromFirestore(cardData, cardId);

      final newReviewDate = DateTime.now();
      final List<DateTime> newReviewDates = List.from(card.reviewDates)..add(newReviewDate);
      final List<int> newRatings = List.from(card.ratings)..add(rating);



      final newDueDate = DateTime.now().add(Duration(days: newInterval));

      await cardRef.update({
        'reviewDates': newReviewDates.map((date) => Timestamp.fromDate(date)).toList(),
        'ratings': newRatings,
        'interval': newInterval,
        'dueDate': Timestamp.fromDate(newDueDate),
        'videoSpeed': newSpeed,
      });

    } catch (e) {
      print('Error in updateVideoCardReview: $e');
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

    try {
      return _firestore
          .collection('users')
          .doc(_auth.currentUser!.email)
          .collection('video_cards')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
        List<VideoCard> cards = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          cards.add(VideoCard.fromFirestore(data, doc.id));
        }
        return cards;
      }).handleError((error) {
        print('Error in getTodayVideoCards stream: $error');
        return [];
      });
    } catch (e) {
      print('Error setting up getTodayVideoCards stream: $e');
      return Stream.value([]);
    }
  }
  Future<void> updateVideoCard(VideoCard card) async {
    try {


      final userEmail = _auth.currentUser!.email!;
      final cardRef = _firestore
          .collection('users')
          .doc(userEmail)
          .collection('video_cards')
          .doc(card.id);

      // Get the current card data to check if the deck has changed
      final currentCardDoc = await cardRef.get();
      final currentCard = VideoCard.fromFirestore(currentCardDoc.data()!, currentCardDoc.id);

      // Start a transaction to ensure atomicity when updating multiple documents
      await _firestore.runTransaction((transaction) async {
        // Update the card
        transaction.update(cardRef, card.toMap());

        // If the deck has changed, update the deck references
        if (currentCard.deckId != card.deckId) {
          // Remove the card reference from the old deck
          if (currentCard.deckId != null) {
            final oldDeckRef = _firestore
                .collection('users')
                .doc(userEmail)
                .collection('decks')
                .doc(currentCard.deckId);
            transaction.update(oldDeckRef, {
              'cardRefs': FieldValue.arrayRemove([card.id])
            });
          }

          // Add the card reference to the new deck
          if (card.deckId != null) {
            final newDeckRef = _firestore
                .collection('users')
                .doc(userEmail)
                .collection('decks')
                .doc(card.deckId);
            transaction.update(newDeckRef, {
              'cardRefs': FieldValue.arrayUnion([card.id])
            });
          }
        }
      });

      print('Video card updated successfully: ${card.id}');
    } catch (e) {
      print('Error in updateVideoCard: $e');
      rethrow;
    }
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
    );
  }
}
class DueCardInfo {
  int shortTermCount = 0;  // interval <= 7
  int mediumTermCount = 0; // 7 < interval <= 30
  int longTermCount = 0;   // 30 < interval

  int get totalCount => shortTermCount + mediumTermCount + longTermCount;
}