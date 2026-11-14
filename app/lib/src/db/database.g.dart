// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> authors =
      GeneratedColumn<String>(
        'authors',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($BooksTable.$converterauthors);
  static const VerificationMeta _isbn13Meta = const VerificationMeta('isbn13');
  @override
  late final GeneratedColumn<String> isbn13 = GeneratedColumn<String>(
    'isbn13',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherMeta = const VerificationMeta(
    'publisher',
  );
  @override
  late final GeneratedColumn<String> publisher = GeneratedColumn<String>(
    'publisher',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publishedDateMeta = const VerificationMeta(
    'publishedDate',
  );
  @override
  late final GeneratedColumn<String> publishedDate = GeneratedColumn<String>(
    'published_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _editionMeta = const VerificationMeta(
    'edition',
  );
  @override
  late final GeneratedColumn<String> edition = GeneratedColumn<String>(
    'edition',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchasedOnMeta = const VerificationMeta(
    'purchasedOn',
  );
  @override
  late final GeneratedColumn<DateTime> purchasedOn = GeneratedColumn<DateTime>(
    'purchased_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverRefMeta = const VerificationMeta(
    'coverRef',
  );
  @override
  late final GeneratedColumn<String> coverRef = GeneratedColumn<String>(
    'cover_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownCoverMeta = const VerificationMeta(
    'ownCover',
  );
  @override
  late final GeneratedColumn<bool> ownCover = GeneratedColumn<bool>(
    'own_cover',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("own_cover" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    authors,
    isbn13,
    publisher,
    publishedDate,
    edition,
    format,
    purchasedOn,
    rating,
    notes,
    status,
    coverRef,
    ownCover,
    addedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('isbn13')) {
      context.handle(
        _isbn13Meta,
        isbn13.isAcceptableOrUnknown(data['isbn13']!, _isbn13Meta),
      );
    }
    if (data.containsKey('publisher')) {
      context.handle(
        _publisherMeta,
        publisher.isAcceptableOrUnknown(data['publisher']!, _publisherMeta),
      );
    }
    if (data.containsKey('published_date')) {
      context.handle(
        _publishedDateMeta,
        publishedDate.isAcceptableOrUnknown(
          data['published_date']!,
          _publishedDateMeta,
        ),
      );
    }
    if (data.containsKey('edition')) {
      context.handle(
        _editionMeta,
        edition.isAcceptableOrUnknown(data['edition']!, _editionMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('purchased_on')) {
      context.handle(
        _purchasedOnMeta,
        purchasedOn.isAcceptableOrUnknown(
          data['purchased_on']!,
          _purchasedOnMeta,
        ),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('cover_ref')) {
      context.handle(
        _coverRefMeta,
        coverRef.isAcceptableOrUnknown(data['cover_ref']!, _coverRefMeta),
      );
    }
    if (data.containsKey('own_cover')) {
      context.handle(
        _ownCoverMeta,
        ownCover.isAcceptableOrUnknown(data['own_cover']!, _ownCoverMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      authors: $BooksTable.$converterauthors.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}authors'],
        )!,
      ),
      isbn13: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isbn13'],
      ),
      publisher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher'],
      ),
      publishedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}published_date'],
      ),
      edition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edition'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      purchasedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}purchased_on'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      coverRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_ref'],
      ),
      ownCover: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}own_cover'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterauthors =
      const StringListConverter();
}

class BookRow extends DataClass implements Insertable<BookRow> {
  /// UUID, so books made on different devices never clash.
  final String id;
  final String title;
  final List<String> authors;
  final String? isbn13;
  final String? publisher;
  final String? publishedDate;
  final String? edition;

  /// `physical` or `kindle` ([OwnershipFormat]).
  final String format;
  final DateTime? purchasedOn;

  /// 0 to 5 stars, or null for not rated.
  final int? rating;
  final String? notes;

  /// `tbr`, `reading`, `read`, `dnf` ([ReadingStatus]), or null (the default).
  final String? status;

  /// Where the downloadable cover comes from: `<sourceId>:<ref>` (e.g. `openlibrary:8750523`).
  final String? coverRef;

  /// True when she has taken or chosen her own cover photo (it wins over [coverRef]).
  final bool ownCover;
  final DateTime addedAt;
  final DateTime updatedAt;
  const BookRow({
    required this.id,
    required this.title,
    required this.authors,
    this.isbn13,
    this.publisher,
    this.publishedDate,
    this.edition,
    required this.format,
    this.purchasedOn,
    this.rating,
    this.notes,
    this.status,
    this.coverRef,
    required this.ownCover,
    required this.addedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    {
      map['authors'] = Variable<String>(
        $BooksTable.$converterauthors.toSql(authors),
      );
    }
    if (!nullToAbsent || isbn13 != null) {
      map['isbn13'] = Variable<String>(isbn13);
    }
    if (!nullToAbsent || publisher != null) {
      map['publisher'] = Variable<String>(publisher);
    }
    if (!nullToAbsent || publishedDate != null) {
      map['published_date'] = Variable<String>(publishedDate);
    }
    if (!nullToAbsent || edition != null) {
      map['edition'] = Variable<String>(edition);
    }
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || purchasedOn != null) {
      map['purchased_on'] = Variable<DateTime>(purchasedOn);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || coverRef != null) {
      map['cover_ref'] = Variable<String>(coverRef);
    }
    map['own_cover'] = Variable<bool>(ownCover);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      authors: Value(authors),
      isbn13: isbn13 == null && nullToAbsent
          ? const Value.absent()
          : Value(isbn13),
      publisher: publisher == null && nullToAbsent
          ? const Value.absent()
          : Value(publisher),
      publishedDate: publishedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedDate),
      edition: edition == null && nullToAbsent
          ? const Value.absent()
          : Value(edition),
      format: Value(format),
      purchasedOn: purchasedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(purchasedOn),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      coverRef: coverRef == null && nullToAbsent
          ? const Value.absent()
          : Value(coverRef),
      ownCover: Value(ownCover),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      authors: serializer.fromJson<List<String>>(json['authors']),
      isbn13: serializer.fromJson<String?>(json['isbn13']),
      publisher: serializer.fromJson<String?>(json['publisher']),
      publishedDate: serializer.fromJson<String?>(json['publishedDate']),
      edition: serializer.fromJson<String?>(json['edition']),
      format: serializer.fromJson<String>(json['format']),
      purchasedOn: serializer.fromJson<DateTime?>(json['purchasedOn']),
      rating: serializer.fromJson<int?>(json['rating']),
      notes: serializer.fromJson<String?>(json['notes']),
      status: serializer.fromJson<String?>(json['status']),
      coverRef: serializer.fromJson<String?>(json['coverRef']),
      ownCover: serializer.fromJson<bool>(json['ownCover']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'authors': serializer.toJson<List<String>>(authors),
      'isbn13': serializer.toJson<String?>(isbn13),
      'publisher': serializer.toJson<String?>(publisher),
      'publishedDate': serializer.toJson<String?>(publishedDate),
      'edition': serializer.toJson<String?>(edition),
      'format': serializer.toJson<String>(format),
      'purchasedOn': serializer.toJson<DateTime?>(purchasedOn),
      'rating': serializer.toJson<int?>(rating),
      'notes': serializer.toJson<String?>(notes),
      'status': serializer.toJson<String?>(status),
      'coverRef': serializer.toJson<String?>(coverRef),
      'ownCover': serializer.toJson<bool>(ownCover),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookRow copyWith({
    String? id,
    String? title,
    List<String>? authors,
    Value<String?> isbn13 = const Value.absent(),
    Value<String?> publisher = const Value.absent(),
    Value<String?> publishedDate = const Value.absent(),
    Value<String?> edition = const Value.absent(),
    String? format,
    Value<DateTime?> purchasedOn = const Value.absent(),
    Value<int?> rating = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> status = const Value.absent(),
    Value<String?> coverRef = const Value.absent(),
    bool? ownCover,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) => BookRow(
    id: id ?? this.id,
    title: title ?? this.title,
    authors: authors ?? this.authors,
    isbn13: isbn13.present ? isbn13.value : this.isbn13,
    publisher: publisher.present ? publisher.value : this.publisher,
    publishedDate: publishedDate.present
        ? publishedDate.value
        : this.publishedDate,
    edition: edition.present ? edition.value : this.edition,
    format: format ?? this.format,
    purchasedOn: purchasedOn.present ? purchasedOn.value : this.purchasedOn,
    rating: rating.present ? rating.value : this.rating,
    notes: notes.present ? notes.value : this.notes,
    status: status.present ? status.value : this.status,
    coverRef: coverRef.present ? coverRef.value : this.coverRef,
    ownCover: ownCover ?? this.ownCover,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      authors: data.authors.present ? data.authors.value : this.authors,
      isbn13: data.isbn13.present ? data.isbn13.value : this.isbn13,
      publisher: data.publisher.present ? data.publisher.value : this.publisher,
      publishedDate: data.publishedDate.present
          ? data.publishedDate.value
          : this.publishedDate,
      edition: data.edition.present ? data.edition.value : this.edition,
      format: data.format.present ? data.format.value : this.format,
      purchasedOn: data.purchasedOn.present
          ? data.purchasedOn.value
          : this.purchasedOn,
      rating: data.rating.present ? data.rating.value : this.rating,
      notes: data.notes.present ? data.notes.value : this.notes,
      status: data.status.present ? data.status.value : this.status,
      coverRef: data.coverRef.present ? data.coverRef.value : this.coverRef,
      ownCover: data.ownCover.present ? data.ownCover.value : this.ownCover,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('authors: $authors, ')
          ..write('isbn13: $isbn13, ')
          ..write('publisher: $publisher, ')
          ..write('publishedDate: $publishedDate, ')
          ..write('edition: $edition, ')
          ..write('format: $format, ')
          ..write('purchasedOn: $purchasedOn, ')
          ..write('rating: $rating, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('coverRef: $coverRef, ')
          ..write('ownCover: $ownCover, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    authors,
    isbn13,
    publisher,
    publishedDate,
    edition,
    format,
    purchasedOn,
    rating,
    notes,
    status,
    coverRef,
    ownCover,
    addedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.authors == this.authors &&
          other.isbn13 == this.isbn13 &&
          other.publisher == this.publisher &&
          other.publishedDate == this.publishedDate &&
          other.edition == this.edition &&
          other.format == this.format &&
          other.purchasedOn == this.purchasedOn &&
          other.rating == this.rating &&
          other.notes == this.notes &&
          other.status == this.status &&
          other.coverRef == this.coverRef &&
          other.ownCover == this.ownCover &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<List<String>> authors;
  final Value<String?> isbn13;
  final Value<String?> publisher;
  final Value<String?> publishedDate;
  final Value<String?> edition;
  final Value<String> format;
  final Value<DateTime?> purchasedOn;
  final Value<int?> rating;
  final Value<String?> notes;
  final Value<String?> status;
  final Value<String?> coverRef;
  final Value<bool> ownCover;
  final Value<DateTime> addedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.authors = const Value.absent(),
    this.isbn13 = const Value.absent(),
    this.publisher = const Value.absent(),
    this.publishedDate = const Value.absent(),
    this.edition = const Value.absent(),
    this.format = const Value.absent(),
    this.purchasedOn = const Value.absent(),
    this.rating = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.coverRef = const Value.absent(),
    this.ownCover = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BooksCompanion.insert({
    required String id,
    required String title,
    this.authors = const Value.absent(),
    this.isbn13 = const Value.absent(),
    this.publisher = const Value.absent(),
    this.publishedDate = const Value.absent(),
    this.edition = const Value.absent(),
    required String format,
    this.purchasedOn = const Value.absent(),
    this.rating = const Value.absent(),
    this.notes = const Value.absent(),
    this.status = const Value.absent(),
    this.coverRef = const Value.absent(),
    this.ownCover = const Value.absent(),
    required DateTime addedAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       addedAt = Value(addedAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? authors,
    Expression<String>? isbn13,
    Expression<String>? publisher,
    Expression<String>? publishedDate,
    Expression<String>? edition,
    Expression<String>? format,
    Expression<DateTime>? purchasedOn,
    Expression<int>? rating,
    Expression<String>? notes,
    Expression<String>? status,
    Expression<String>? coverRef,
    Expression<bool>? ownCover,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (authors != null) 'authors': authors,
      if (isbn13 != null) 'isbn13': isbn13,
      if (publisher != null) 'publisher': publisher,
      if (publishedDate != null) 'published_date': publishedDate,
      if (edition != null) 'edition': edition,
      if (format != null) 'format': format,
      if (purchasedOn != null) 'purchased_on': purchasedOn,
      if (rating != null) 'rating': rating,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
      if (coverRef != null) 'cover_ref': coverRef,
      if (ownCover != null) 'own_cover': ownCover,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<List<String>>? authors,
    Value<String?>? isbn13,
    Value<String?>? publisher,
    Value<String?>? publishedDate,
    Value<String?>? edition,
    Value<String>? format,
    Value<DateTime?>? purchasedOn,
    Value<int?>? rating,
    Value<String?>? notes,
    Value<String?>? status,
    Value<String?>? coverRef,
    Value<bool>? ownCover,
    Value<DateTime>? addedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      isbn13: isbn13 ?? this.isbn13,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      edition: edition ?? this.edition,
      format: format ?? this.format,
      purchasedOn: purchasedOn ?? this.purchasedOn,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      coverRef: coverRef ?? this.coverRef,
      ownCover: ownCover ?? this.ownCover,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (authors.present) {
      map['authors'] = Variable<String>(
        $BooksTable.$converterauthors.toSql(authors.value),
      );
    }
    if (isbn13.present) {
      map['isbn13'] = Variable<String>(isbn13.value);
    }
    if (publisher.present) {
      map['publisher'] = Variable<String>(publisher.value);
    }
    if (publishedDate.present) {
      map['published_date'] = Variable<String>(publishedDate.value);
    }
    if (edition.present) {
      map['edition'] = Variable<String>(edition.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (purchasedOn.present) {
      map['purchased_on'] = Variable<DateTime>(purchasedOn.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (coverRef.present) {
      map['cover_ref'] = Variable<String>(coverRef.value);
    }
    if (ownCover.present) {
      map['own_cover'] = Variable<bool>(ownCover.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('authors: $authors, ')
          ..write('isbn13: $isbn13, ')
          ..write('publisher: $publisher, ')
          ..write('publishedDate: $publishedDate, ')
          ..write('edition: $edition, ')
          ..write('format: $format, ')
          ..write('purchasedOn: $purchasedOn, ')
          ..write('rating: $rating, ')
          ..write('notes: $notes, ')
          ..write('status: $status, ')
          ..write('coverRef: $coverRef, ')
          ..write('ownCover: $ownCover, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookIdentifiersTable extends BookIdentifiers
    with TableInfo<$BookIdentifiersTable, BookIdentifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookIdentifiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _schemeMeta = const VerificationMeta('scheme');
  @override
  late final GeneratedColumn<String> scheme = GeneratedColumn<String>(
    'scheme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, scheme, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_identifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookIdentifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('scheme')) {
      context.handle(
        _schemeMeta,
        scheme.isAcceptableOrUnknown(data['scheme']!, _schemeMeta),
      );
    } else if (isInserting) {
      context.missing(_schemeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, scheme, value};
  @override
  BookIdentifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookIdentifier(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      scheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $BookIdentifiersTable createAlias(String alias) {
    return $BookIdentifiersTable(attachedDatabase, alias);
  }
}

class BookIdentifier extends DataClass implements Insertable<BookIdentifier> {
  final String bookId;
  final String scheme;
  final String value;
  const BookIdentifier({
    required this.bookId,
    required this.scheme,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['scheme'] = Variable<String>(scheme);
    map['value'] = Variable<String>(value);
    return map;
  }

  BookIdentifiersCompanion toCompanion(bool nullToAbsent) {
    return BookIdentifiersCompanion(
      bookId: Value(bookId),
      scheme: Value(scheme),
      value: Value(value),
    );
  }

  factory BookIdentifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookIdentifier(
      bookId: serializer.fromJson<String>(json['bookId']),
      scheme: serializer.fromJson<String>(json['scheme']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'scheme': serializer.toJson<String>(scheme),
      'value': serializer.toJson<String>(value),
    };
  }

  BookIdentifier copyWith({String? bookId, String? scheme, String? value}) =>
      BookIdentifier(
        bookId: bookId ?? this.bookId,
        scheme: scheme ?? this.scheme,
        value: value ?? this.value,
      );
  BookIdentifier copyWithCompanion(BookIdentifiersCompanion data) {
    return BookIdentifier(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      scheme: data.scheme.present ? data.scheme.value : this.scheme,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookIdentifier(')
          ..write('bookId: $bookId, ')
          ..write('scheme: $scheme, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, scheme, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookIdentifier &&
          other.bookId == this.bookId &&
          other.scheme == this.scheme &&
          other.value == this.value);
}

class BookIdentifiersCompanion extends UpdateCompanion<BookIdentifier> {
  final Value<String> bookId;
  final Value<String> scheme;
  final Value<String> value;
  final Value<int> rowid;
  const BookIdentifiersCompanion({
    this.bookId = const Value.absent(),
    this.scheme = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookIdentifiersCompanion.insert({
    required String bookId,
    required String scheme,
    required String value,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       scheme = Value(scheme),
       value = Value(value);
  static Insertable<BookIdentifier> custom({
    Expression<String>? bookId,
    Expression<String>? scheme,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (scheme != null) 'scheme': scheme,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookIdentifiersCompanion copyWith({
    Value<String>? bookId,
    Value<String>? scheme,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return BookIdentifiersCompanion(
      bookId: bookId ?? this.bookId,
      scheme: scheme ?? this.scheme,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (scheme.present) {
      map['scheme'] = Variable<String>(scheme.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookIdentifiersCompanion(')
          ..write('bookId: $bookId, ')
          ..write('scheme: $scheme, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookGenresTable extends BookGenres
    with TableInfo<$BookGenresTable, BookGenre> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookGenresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bookId, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookGenre> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, name};
  @override
  BookGenre map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookGenre(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $BookGenresTable createAlias(String alias) {
    return $BookGenresTable(attachedDatabase, alias);
  }
}

class BookGenre extends DataClass implements Insertable<BookGenre> {
  final String bookId;
  final String name;
  const BookGenre({required this.bookId, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    return map;
  }

  BookGenresCompanion toCompanion(bool nullToAbsent) {
    return BookGenresCompanion(bookId: Value(bookId), name: Value(name));
  }

  factory BookGenre.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookGenre(
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
    };
  }

  BookGenre copyWith({String? bookId, String? name}) =>
      BookGenre(bookId: bookId ?? this.bookId, name: name ?? this.name);
  BookGenre copyWithCompanion(BookGenresCompanion data) {
    return BookGenre(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookGenre(')
          ..write('bookId: $bookId, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bookId, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookGenre &&
          other.bookId == this.bookId &&
          other.name == this.name);
}

class BookGenresCompanion extends UpdateCompanion<BookGenre> {
  final Value<String> bookId;
  final Value<String> name;
  final Value<int> rowid;
  const BookGenresCompanion({
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookGenresCompanion.insert({
    required String bookId,
    required String name,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       name = Value(name);
  static Insertable<BookGenre> custom({
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookGenresCompanion copyWith({
    Value<String>? bookId,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return BookGenresCompanion(
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookGenresCompanion(')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChangeLogTable extends ChangeLog
    with TableInfo<$ChangeLogTable, ChangeLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangeLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [seq, bookId, field, value, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'change_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  ChangeLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeLogData(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $ChangeLogTable createAlias(String alias) {
    return $ChangeLogTable(attachedDatabase, alias);
  }
}

class ChangeLogData extends DataClass implements Insertable<ChangeLogData> {
  final int seq;
  final String bookId;

  /// A field name, `genres`, `identifiers`, `created` or `deleted`.
  final String field;

  /// The new value as JSON (null for a deletion).
  final String? value;
  final DateTime at;
  const ChangeLogData({
    required this.seq,
    required this.bookId,
    required this.field,
    this.value,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['book_id'] = Variable<String>(bookId);
    map['field'] = Variable<String>(field);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  ChangeLogCompanion toCompanion(bool nullToAbsent) {
    return ChangeLogCompanion(
      seq: Value(seq),
      bookId: Value(bookId),
      field: Value(field),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      at: Value(at),
    );
  }

  factory ChangeLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeLogData(
      seq: serializer.fromJson<int>(json['seq']),
      bookId: serializer.fromJson<String>(json['bookId']),
      field: serializer.fromJson<String>(json['field']),
      value: serializer.fromJson<String?>(json['value']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'bookId': serializer.toJson<String>(bookId),
      'field': serializer.toJson<String>(field),
      'value': serializer.toJson<String?>(value),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  ChangeLogData copyWith({
    int? seq,
    String? bookId,
    String? field,
    Value<String?> value = const Value.absent(),
    DateTime? at,
  }) => ChangeLogData(
    seq: seq ?? this.seq,
    bookId: bookId ?? this.bookId,
    field: field ?? this.field,
    value: value.present ? value.value : this.value,
    at: at ?? this.at,
  );
  ChangeLogData copyWithCompanion(ChangeLogCompanion data) {
    return ChangeLogData(
      seq: data.seq.present ? data.seq.value : this.seq,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      field: data.field.present ? data.field.value : this.field,
      value: data.value.present ? data.value.value : this.value,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogData(')
          ..write('seq: $seq, ')
          ..write('bookId: $bookId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, bookId, field, value, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeLogData &&
          other.seq == this.seq &&
          other.bookId == this.bookId &&
          other.field == this.field &&
          other.value == this.value &&
          other.at == this.at);
}

class ChangeLogCompanion extends UpdateCompanion<ChangeLogData> {
  final Value<int> seq;
  final Value<String> bookId;
  final Value<String> field;
  final Value<String?> value;
  final Value<DateTime> at;
  const ChangeLogCompanion({
    this.seq = const Value.absent(),
    this.bookId = const Value.absent(),
    this.field = const Value.absent(),
    this.value = const Value.absent(),
    this.at = const Value.absent(),
  });
  ChangeLogCompanion.insert({
    this.seq = const Value.absent(),
    required String bookId,
    required String field,
    this.value = const Value.absent(),
    required DateTime at,
  }) : bookId = Value(bookId),
       field = Value(field),
       at = Value(at);
  static Insertable<ChangeLogData> custom({
    Expression<int>? seq,
    Expression<String>? bookId,
    Expression<String>? field,
    Expression<String>? value,
    Expression<DateTime>? at,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (bookId != null) 'book_id': bookId,
      if (field != null) 'field': field,
      if (value != null) 'value': value,
      if (at != null) 'at': at,
    });
  }

  ChangeLogCompanion copyWith({
    Value<int>? seq,
    Value<String>? bookId,
    Value<String>? field,
    Value<String?>? value,
    Value<DateTime>? at,
  }) {
    return ChangeLogCompanion(
      seq: seq ?? this.seq,
      bookId: bookId ?? this.bookId,
      field: field ?? this.field,
      value: value ?? this.value,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogCompanion(')
          ..write('seq: $seq, ')
          ..write('bookId: $bookId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $BookIdentifiersTable bookIdentifiers = $BookIdentifiersTable(
    this,
  );
  late final $BookGenresTable bookGenres = $BookGenresTable(this);
  late final $ChangeLogTable changeLog = $ChangeLogTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    bookIdentifiers,
    bookGenres,
    changeLog,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_identifiers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('book_genres', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  required String id,
  required String title,
  Value<List<String>> authors,
  Value<String?> isbn13,
  Value<String?> publisher,
  Value<String?> publishedDate,
  Value<String?> edition,
  required String format,
  Value<DateTime?> purchasedOn,
  Value<int?> rating,
  Value<String?> notes,
  Value<String?> status,
  Value<String?> coverRef,
  Value<bool> ownCover,
  required DateTime addedAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<List<String>> authors,
  Value<String?> isbn13,
  Value<String?> publisher,
  Value<String?> publishedDate,
  Value<String?> edition,
  Value<String> format,
  Value<DateTime?> purchasedOn,
  Value<int?> rating,
  Value<String?> notes,
  Value<String?> status,
  Value<String?> coverRef,
  Value<bool> ownCover,
  Value<DateTime> addedAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, BookRow> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BookIdentifiersTable, List<BookIdentifier>>
  _bookIdentifiersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookIdentifiers,
    aliasName: 'books__id__book_identifiers__book_id',
  );

  $$BookIdentifiersTableProcessedTableManager get bookIdentifiersRefs {
    final manager = $$BookIdentifiersTableTableManager(
      $_db,
      $_db.bookIdentifiers,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _bookIdentifiersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookGenresTable, List<BookGenre>>
  _bookGenresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookGenres,
    aliasName: 'books__id__book_genres__book_id',
  );

  $$BookGenresTableProcessedTableManager get bookGenresRefs {
    final manager = $$BookGenresTableTableManager(
      $_db,
      $_db.bookGenres,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookGenresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get authors => $composableBuilder(
    column: $table.authors,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get isbn13 => $composableBuilder(
    column: $table.isbn13,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publishedDate => $composableBuilder(
    column: $table.publishedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get purchasedOn => $composableBuilder(
    column: $table.purchasedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverRef => $composableBuilder(
    column: $table.coverRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ownCover => $composableBuilder(
    column: $table.ownCover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bookIdentifiersRefs(
    Expression<bool> Function($$BookIdentifiersTableFilterComposer f) f,
  ) {
    final $$BookIdentifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookIdentifiers,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookIdentifiersTableFilterComposer(
            $db: $db,
            $table: $db.bookIdentifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookGenresRefs(
    Expression<bool> Function($$BookGenresTableFilterComposer f) f,
  ) {
    final $$BookGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookGenres,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookGenresTableFilterComposer(
            $db: $db,
            $table: $db.bookGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authors => $composableBuilder(
    column: $table.authors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isbn13 => $composableBuilder(
    column: $table.isbn13,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publishedDate => $composableBuilder(
    column: $table.publishedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get purchasedOn => $composableBuilder(
    column: $table.purchasedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverRef => $composableBuilder(
    column: $table.coverRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ownCover => $composableBuilder(
    column: $table.ownCover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get authors =>
      $composableBuilder(column: $table.authors, builder: (column) => column);

  GeneratedColumn<String> get isbn13 =>
      $composableBuilder(column: $table.isbn13, builder: (column) => column);

  GeneratedColumn<String> get publisher =>
      $composableBuilder(column: $table.publisher, builder: (column) => column);

  GeneratedColumn<String> get publishedDate => $composableBuilder(
    column: $table.publishedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get edition =>
      $composableBuilder(column: $table.edition, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<DateTime> get purchasedOn => $composableBuilder(
    column: $table.purchasedOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get coverRef =>
      $composableBuilder(column: $table.coverRef, builder: (column) => column);

  GeneratedColumn<bool> get ownCover =>
      $composableBuilder(column: $table.ownCover, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> bookIdentifiersRefs<T extends Object>(
    Expression<T> Function($$BookIdentifiersTableAnnotationComposer a) f,
  ) {
    final $$BookIdentifiersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookIdentifiers,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookIdentifiersTableAnnotationComposer(
            $db: $db,
            $table: $db.bookIdentifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookGenresRefs<T extends Object>(
    Expression<T> Function($$BookGenresTableAnnotationComposer a) f,
  ) {
    final $$BookGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookGenres,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.bookGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          BookRow,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRow, $$BooksTableReferences),
          BookRow,
          PrefetchHooks Function({
            bool bookIdentifiersRefs,
            bool bookGenresRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<List<String>> authors = const Value.absent(),
                Value<String?> isbn13 = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<String?> publishedDate = const Value.absent(),
                Value<String?> edition = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<DateTime?> purchasedOn = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> coverRef = const Value.absent(),
                Value<bool> ownCover = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                authors: authors,
                isbn13: isbn13,
                publisher: publisher,
                publishedDate: publishedDate,
                edition: edition,
                format: format,
                purchasedOn: purchasedOn,
                rating: rating,
                notes: notes,
                status: status,
                coverRef: coverRef,
                ownCover: ownCover,
                addedAt: addedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<List<String>> authors = const Value.absent(),
                Value<String?> isbn13 = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<String?> publishedDate = const Value.absent(),
                Value<String?> edition = const Value.absent(),
                required String format,
                Value<DateTime?> purchasedOn = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> coverRef = const Value.absent(),
                Value<bool> ownCover = const Value.absent(),
                required DateTime addedAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                authors: authors,
                isbn13: isbn13,
                publisher: publisher,
                publishedDate: publishedDate,
                edition: edition,
                format: format,
                purchasedOn: purchasedOn,
                rating: rating,
                notes: notes,
                status: status,
                coverRef: coverRef,
                ownCover: ownCover,
                addedAt: addedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, BookRow>(table),
                  $$BooksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bookIdentifiersRefs = false, bookGenresRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bookIdentifiersRefs) db.bookIdentifiers,
                    if (bookGenresRefs) db.bookGenres,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bookIdentifiersRefs)
                        await $_getPrefetchedDataByColumns<
                          BookRow,
                          $BooksTable,
                          BookIdentifier,
                          $BookIdentifiersTable
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookIdentifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookIdentifiersRefs,
                          currentColumn: 'id',
                          referencedColumn: 'book_id',
                          typedResults: items,
                        ),
                      if (bookGenresRefs)
                        await $_getPrefetchedDataByColumns<
                          BookRow,
                          $BooksTable,
                          BookGenre,
                          $BookGenresTable
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookGenresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookGenresRefs,
                          currentColumn: 'id',
                          referencedColumn: 'book_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      BookRow,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRow, $$BooksTableReferences),
      BookRow,
      PrefetchHooks Function({bool bookIdentifiersRefs, bool bookGenresRefs})
    >;
typedef $$BookIdentifiersTableCreateCompanionBuilder =
    BookIdentifiersCompanion Function({
      required String bookId,
      required String scheme,
      required String value,
      Value<int> rowid,
    });
typedef $$BookIdentifiersTableUpdateCompanionBuilder =
    BookIdentifiersCompanion Function({
      Value<String> bookId,
      Value<String> scheme,
      Value<String> value,
      Value<int> rowid,
    });

final class $$BookIdentifiersTableReferences
    extends
        BaseReferences<_$AppDatabase, $BookIdentifiersTable, BookIdentifier> {
  $$BookIdentifiersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_identifiers__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookIdentifiersTableFilterComposer
    extends Composer<_$AppDatabase, $BookIdentifiersTable> {
  $$BookIdentifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookIdentifiersTableOrderingComposer
    extends Composer<_$AppDatabase, $BookIdentifiersTable> {
  $$BookIdentifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookIdentifiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookIdentifiersTable> {
  $$BookIdentifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scheme =>
      $composableBuilder(column: $table.scheme, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookIdentifiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookIdentifiersTable,
          BookIdentifier,
          $$BookIdentifiersTableFilterComposer,
          $$BookIdentifiersTableOrderingComposer,
          $$BookIdentifiersTableAnnotationComposer,
          $$BookIdentifiersTableCreateCompanionBuilder,
          $$BookIdentifiersTableUpdateCompanionBuilder,
          (BookIdentifier, $$BookIdentifiersTableReferences),
          BookIdentifier,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookIdentifiersTableTableManager(
    _$AppDatabase db,
    $BookIdentifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookIdentifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookIdentifiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookIdentifiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> scheme = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookIdentifiersCompanion(
                bookId: bookId,
                scheme: scheme,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String scheme,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => BookIdentifiersCompanion.insert(
                bookId: bookId,
                scheme: scheme,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookIdentifiersTable, BookIdentifier>(table),
                  $$BookIdentifiersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$BookIdentifiersTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$BookIdentifiersTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookIdentifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookIdentifiersTable,
      BookIdentifier,
      $$BookIdentifiersTableFilterComposer,
      $$BookIdentifiersTableOrderingComposer,
      $$BookIdentifiersTableAnnotationComposer,
      $$BookIdentifiersTableCreateCompanionBuilder,
      $$BookIdentifiersTableUpdateCompanionBuilder,
      (BookIdentifier, $$BookIdentifiersTableReferences),
      BookIdentifier,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$BookGenresTableCreateCompanionBuilder = BookGenresCompanion Function({
  required String bookId,
  required String name,
  Value<int> rowid,
});
typedef $$BookGenresTableUpdateCompanionBuilder = BookGenresCompanion Function({
  Value<String> bookId,
  Value<String> name,
  Value<int> rowid,
});

final class $$BookGenresTableReferences
    extends BaseReferences<_$AppDatabase, $BookGenresTable, BookGenre> {
  $$BookGenresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) =>
      db.books.createAlias('book_genres__book_id__books__id');

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookGenresTableFilterComposer
    extends Composer<_$AppDatabase, $BookGenresTable> {
  $$BookGenresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookGenresTableOrderingComposer
    extends Composer<_$AppDatabase, $BookGenresTable> {
  $$BookGenresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookGenresTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookGenresTable> {
  $$BookGenresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookGenresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookGenresTable,
          BookGenre,
          $$BookGenresTableFilterComposer,
          $$BookGenresTableOrderingComposer,
          $$BookGenresTableAnnotationComposer,
          $$BookGenresTableCreateCompanionBuilder,
          $$BookGenresTableUpdateCompanionBuilder,
          (BookGenre, $$BookGenresTableReferences),
          BookGenre,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookGenresTableTableManager(_$AppDatabase db, $BookGenresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookGenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookGenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookGenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> bookId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BookGenresCompanion(bookId: bookId, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String bookId,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => BookGenresCompanion.insert(
                bookId: bookId,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookGenresTable, BookGenre>(table),
                  $$BookGenresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$BookGenresTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$BookGenresTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookGenresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookGenresTable,
      BookGenre,
      $$BookGenresTableFilterComposer,
      $$BookGenresTableOrderingComposer,
      $$BookGenresTableAnnotationComposer,
      $$BookGenresTableCreateCompanionBuilder,
      $$BookGenresTableUpdateCompanionBuilder,
      (BookGenre, $$BookGenresTableReferences),
      BookGenre,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$ChangeLogTableCreateCompanionBuilder = ChangeLogCompanion Function({
  Value<int> seq,
  required String bookId,
  required String field,
  Value<String?> value,
  required DateTime at,
});
typedef $$ChangeLogTableUpdateCompanionBuilder = ChangeLogCompanion Function({
  Value<int> seq,
  Value<String> bookId,
  Value<String> field,
  Value<String?> value,
  Value<DateTime> at,
});

class $$ChangeLogTableFilterComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangeLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangeLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChangeLogTable> {
  $$ChangeLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$ChangeLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChangeLogTable,
          ChangeLogData,
          $$ChangeLogTableFilterComposer,
          $$ChangeLogTableOrderingComposer,
          $$ChangeLogTableAnnotationComposer,
          $$ChangeLogTableCreateCompanionBuilder,
          $$ChangeLogTableUpdateCompanionBuilder,
          (
            ChangeLogData,
            BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogData>,
          ),
          ChangeLogData,
          PrefetchHooks Function()
        > {
  $$ChangeLogTableTableManager(_$AppDatabase db, $ChangeLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChangeLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChangeLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChangeLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => ChangeLogCompanion(
                seq: seq,
                bookId: bookId,
                field: field,
                value: value,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String bookId,
                required String field,
                Value<String?> value = const Value.absent(),
                required DateTime at,
              }) => ChangeLogCompanion.insert(
                seq: seq,
                bookId: bookId,
                field: field,
                value: value,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChangeLogTable, ChangeLogData>(table),
                  BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangeLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChangeLogTable,
      ChangeLogData,
      $$ChangeLogTableFilterComposer,
      $$ChangeLogTableOrderingComposer,
      $$ChangeLogTableAnnotationComposer,
      $$ChangeLogTableCreateCompanionBuilder,
      $$ChangeLogTableUpdateCompanionBuilder,
      (
        ChangeLogData,
        BaseReferences<_$AppDatabase, $ChangeLogTable, ChangeLogData>,
      ),
      ChangeLogData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$BookIdentifiersTableTableManager get bookIdentifiers =>
      $$BookIdentifiersTableTableManager(_db, _db.bookIdentifiers);
  $$BookGenresTableTableManager get bookGenres =>
      $$BookGenresTableTableManager(_db, _db.bookGenres);
  $$ChangeLogTableTableManager get changeLog =>
      $$ChangeLogTableTableManager(_db, _db.changeLog);
}
