import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/deck_service.dart';
import 'package:flutter/material.dart';
import '../services/deck_service.dart';
import '../services/video_card_service.dart';
import '/widgets/edit_card_dialog.dart';

class LocalCacheService {
  static const String _decksKey = 'decks_cache';
  static const String _videoCardsKey = 'video_cards_cache';
  final SharedPreferences _prefs;

  LocalCacheService(this._prefs);

  // Factory constructor to initialize SharedPreferences
  static Future<LocalCacheService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalCacheService(prefs);
  }

  // Cache decks
  Future<void> cacheDecks(List<Deck> decks) async {
    final decksJson = decks.map((deck) => {
      'id': deck.id,
      'name': deck.name,
    }).toList();
    await _prefs.setString(_decksKey, jsonEncode(decksJson));
  }

  // Get cached decks
  List<Deck>? getCachedDecks() {
    final cachedData = _prefs.getString(_decksKey);
    if (cachedData == null) return null;

    try {
      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded.map((json) => Deck(
        id: json['id'],
        name: json['name'],
      )).toList();
    } catch (e) {
      print('Error decoding cached decks: $e');
      return null;
    }
  }

  // Cache video cards for a specific deck
  Future<void> cacheVideoCards(String deckId, List<VideoCard> cards) async {
    final cardsJson = cards.map((card) => {
      'id': card.id,
      'videoId': card.videoId,
      'startTime': card.startTime,
      'endTime': card.endTime,
      'answer': card.answer,
      'deckId': card.deckId,
      'deckName': card.deckName,
      'createdAt': card.createdAt.toIso8601String(),
      'reviewDates': card.reviewDates.map((date) => date.toIso8601String()).toList(),
      'ratings': card.ratings,
      'interval': card.interval,
      'dueDate': card.dueDate.toIso8601String(),
    }).toList();
    await _prefs.setString('${_videoCardsKey}_$deckId', jsonEncode(cardsJson));
  }

  // Get cached video cards for a specific deck
  List<VideoCard>? getCachedVideoCards(String deckId) {
    final cachedData = _prefs.getString('${_videoCardsKey}_$deckId');
    if (cachedData == null) return null;

    try {
      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded.map((json) => VideoCard(
        id: json['id'],
        videoId: json['videoId'],
        videoTitle: json['videoTitle'],
        startTime: json['startTime'].toDouble(),
        endTime: json['endTime'].toDouble(),
        answer: json['answer'],
        deckId: json['deckId'],
        deckName: json['deckName'],
        createdAt: DateTime.parse(json['createdAt']),
        reviewDates: (json['reviewDates'] as List)
            .map((date) => DateTime.parse(date))
            .toList(),
        ratings: List<int>.from(json['ratings']),
        interval: json['interval'],
        overdue: json['overdue'],
        dueDate: DateTime.parse(json['dueDate']),
      )).toList();
    } catch (e) {
      print('Error decoding cached video cards: $e');
      return null;
    }
  }

  // Clear cache for a specific deck
  Future<void> clearDeckCache(String deckId) async {
    await _prefs.remove('${_videoCardsKey}_$deckId');
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    await _prefs.remove(_decksKey);
    final allKeys = _prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith(_videoCardsKey)) {
        await _prefs.remove(key);
      }
    }
  }
}