/// Open Library (openlibrary.org). Limits and terms: docs/open-library.md.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../books/models.dart';
import 'book_source.dart';

class OpenLibrarySource implements BookSource, SeriesSource {
  OpenLibrarySource({http.Client? client, this.appVersion = '0.1.0'}) : _client = client ?? http.Client();

  static const _base = 'https://openlibrary.org';
  final http.Client _client;
  final String appVersion;

  // Identified clients may make 3 requests a second; stay under it.
  static const _gap = Duration(milliseconds: 400);
  DateTime _next = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String get id => 'openlibrary';
  @override
  String get name => 'Open Library';

  Map<String, String>? get _headers =>
      kIsWeb ? null : {'User-Agent': 'Tsundoku/$appVersion (+https://github.com/MysteryGodzilla/tsundoku)'};

  Future<void> _throttle() async {
    final now = DateTime.now();
    if (now.isBefore(_next)) await Future<void>.delayed(_next.difference(now));
    _next = DateTime.now().add(_gap);
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    await _throttle();
    final r = await _client.get(Uri.parse('$_base$path'), headers: _headers).timeout(const Duration(seconds: 20));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw OpenLibraryException('Open Library answered ${r.statusCode}');
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    return body is Map<String, dynamic> ? body : null;
  }

  static List<String> _keys(Object? list, [String? nested]) => ((list as List?) ?? const [])
      .map((e) => nested == null ? (e as Map)['key'] : ((e as Map)[nested] as Map?)?['key'])
      .whereType<String>()
      .toList();

  static String _stripPrefix(String key) => key.split('/').last;

  /// Series names by key: a series is shared by many books, so each is fetched once.
  final _seriesNames = <String, String?>{};

  /// A work's series, from its `series` list (`[{series: {key}, position}]`, Open Library's
  /// series records, 2026). The free-text `series` on editions is ignored: it mixes publishers'
  /// imprints, other languages and odd numbering.
  Future<BookSeries?> _seriesOfWork(Map<String, dynamic>? w) async {
    for (final s in ((w?['series'] as List?) ?? const []).whereType<Map>()) {
      final key = (s['series'] as Map?)?['key'] as String?;
      if (key == null || !key.startsWith('/series/')) continue;
      final name = _seriesNames.containsKey(key) ? _seriesNames[key] : (_seriesNames[key] = (await _getJson('$key.json'))?['name'] as String?);
      if (name == null || name.trim().isEmpty) continue;
      final position = s['position'];
      return BookSeries(name.trim(), position == null || '$position'.trim().isEmpty ? null : '$position'.trim());
    }
    return null;
  }

  @override
  Future<BookSeries?> seriesFor(List<Identifier> identifiers) async {
    final work = identifiers.where((i) => i.scheme == Schemes.openLibraryWork).firstOrNull;
    if (work == null) return null;
    return _seriesOfWork(await _getJson('/works/${work.value}.json'));
  }

  @override
  Future<Candidate?> lookupIsbn(String isbn13) async {
    final e = await _getJson('/isbn/$isbn13.json');
    if (e == null || e['title'] == null) return null;
    final workKey = _keys(e['works']).firstOrNull;
    var authorKeys = _keys(e['authors']);
    List<String> subjects = ((e['subjects'] as List?) ?? const []).whereType<String>().toList();
    BookSeries? series;
    if (workKey != null) {
      // The work holds the series (and fills in authors or subjects the edition lacks).
      final w = await _getJson('$workKey.json');
      if (authorKeys.isEmpty) authorKeys = _keys(w?['authors'], 'author');
      if (subjects.isEmpty) subjects = ((w?['subjects'] as List?) ?? const []).whereType<String>().toList();
      series = await _seriesOfWork(w);
    }
    final authors = <String>[];
    for (final k in authorKeys.take(4)) {
      final a = await _getJson('$k.json');
      final n = a?['name'] as String?;
      if (n != null) authors.add(n);
    }
    final covers = ((e['covers'] as List?) ?? const []).whereType<int>().where((c) => c > 0);
    final editionKey = e['key'] as String?;
    final title = [e['title'] as String, if (e['subtitle'] is String) e['subtitle'] as String].join(': ');
    return Candidate(
      sourceId: id,
      title: title,
      authors: authors,
      isbn13: isbn13,
      publisher: ((e['publishers'] as List?) ?? const []).whereType<String>().firstOrNull,
      publishedDate: e['publish_date'] as String?,
      edition: e['physical_format'] as String?,
      subjects: subjects,
      coverRef: covers.isEmpty ? null : '${covers.first}',
      identifiers: [
        if (workKey != null) Identifier(Schemes.openLibraryWork, _stripPrefix(workKey)),
        if (editionKey != null) Identifier(Schemes.openLibraryEdition, _stripPrefix(editionKey)),
      ],
      series: series,
    );
  }

  @override
  Future<List<Candidate>> search(String query) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final d = await _getJson('/search.json?q=$q&limit=20'
        '&fields=key,title,subtitle,author_name,cover_i,first_publish_year,publisher,subject');
    final docs = (d?['docs'] as List?) ?? const [];
    return [
      for (final x in docs.whereType<Map>())
        if (x['title'] is String)
          Candidate(
            sourceId: id,
            title: [x['title'] as String, if (x['subtitle'] is String) x['subtitle'] as String].join(': '),
            authors: ((x['author_name'] as List?) ?? const []).whereType<String>().toList(),
            publishedDate: x['first_publish_year']?.toString(),
            publisher: ((x['publisher'] as List?) ?? const []).whereType<String>().firstOrNull,
            subjects: ((x['subject'] as List?) ?? const []).whereType<String>().take(12).toList(),
            coverRef: x['cover_i'] is int ? '${x['cover_i']}' : null,
            identifiers: [
              if (x['key'] is String) Identifier(Schemes.openLibraryWork, _stripPrefix(x['key'] as String)),
            ],
          ),
    ];
  }

  @override
  Uri? coverUri(String ref, CoverSize size) {
    final s = switch (size) { CoverSize.small => 'S', CoverSize.medium => 'M', CoverSize.large => 'L' };
    return int.tryParse(ref) == null ? null : Uri.parse('https://covers.openlibrary.org/b/id/$ref-$s.jpg?default=false');
  }
}

class OpenLibraryException implements Exception {
  OpenLibraryException(this.message);
  final String message;
  @override
  String toString() => message;
}
