import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPreferences {
  final double speedAddCard;
  final String theme;
  final String reviewOrder;

  UserPreferences({
    this.speedAddCard = 1.0,
    this.theme = "Dark",
    this.reviewOrder = "IntervalAscending",
  });

  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserPreferences(
      speedAddCard: data['speedAddCard'] != null ? (data['speedAddCard'] is int ? (data['speedAddCard'] as int).toDouble() : data['speedAddCard']) : 1.0,
      theme: data['theme'] ?? 'Dark',
      reviewOrder: data['reviewOrder'] ?? 'IntervalAscending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'speedAddCard': speedAddCard,
      'theme': theme,
      'reviewOrder': reviewOrder,
    };
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initializeUserPreferences() async {
    if (_auth.currentUser == null) {
      throw Exception('Người dùng phải đăng nhập để khởi tạo preferences');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('Không tìm thấy email người dùng');
      }

      final userDoc = await _firestore.collection('users').doc(userEmail).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userEmail).set({
          'speedAddCard': 1.0,
          'theme': 'Dark',
          'reviewOrder': 'IntervalAscending',
        });
      }
    } catch (e) {
      print('Lỗi khởi tạo user preferences: $e');
      throw Exception('Không thể khởi tạo user preferences');
    }
  }

  Future<void> updateUserPreferences({
    double? speedAddCard,
    String? theme,
    String? reviewOrder,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('Người dùng phải đăng nhập để cập nhật preferences');
    }

    try {
      String? userEmail = _auth.currentUser!.email;
      if (userEmail == null) {
        throw Exception('Không tìm thấy email người dùng');
      }

      Map<String, dynamic> updateData = {};
      if (speedAddCard != null) updateData['speedAddCard'] = speedAddCard;
      if (theme != null) updateData['theme'] = theme;
      if (reviewOrder != null) updateData['reviewOrder'] = reviewOrder;

      await _firestore
          .collection('users')
          .doc(userEmail)
          .update(updateData);

      print('User preferences đã được cập nhật thành công');
    } catch (e) {
      print('Lỗi cập nhật user preferences: $e');
      throw Exception('Không thể cập nhật user preferences');
    }
  }

  Stream<UserPreferences> getUserPreferences() {
    if (_auth.currentUser == null || _auth.currentUser!.email == null) {
      return Stream.value(UserPreferences());
    }

    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.email)
        .snapshots()
        .map((doc) => doc.exists
        ? UserPreferences.fromFirestore(doc)
        : UserPreferences());
  }
}